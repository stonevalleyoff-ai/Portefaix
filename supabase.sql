-- Portefaix — les salons en ligne (supabase.sql), dans le Supabase de Stone Valley (« Vallée de pierre »)
-- Trois tables et six fonctions, toutes préfixées « pf_ » ; rien de Stone Valley (vp_…) n'est touché.
-- Supabase ne porte que le salon : son code, qui y est, et les messages de mise en relation (WebRTC). La partie, elle, passe
-- directement d'un joueur à l'autre.
-- Les tables sont fermées (RLS sans règle) : on n'y accède que par les fonctions, réservées aux comptes connectés.
-- Pour tout retirer : la fin de ce fichier.

create table public.pf_salons (
  code text primary key,
  hote uuid not null references auth.users (id) on delete cascade,
  etat text not null default 'ouvert' check (etat in ('ouvert', 'parti')),
  cree_le timestamptz not null default now(),
  vu_le timestamptz not null default now()
);
comment on table public.pf_salons is 'Salons en ligne de Portefaix. Accès uniquement par les fonctions pf_salon_*.';

create table public.pf_membres (
  code text not null references public.pf_salons (code) on delete cascade,
  utilisateur uuid not null references auth.users (id) on delete cascade,
  numero int not null,
  pseudo text not null,
  vu_le timestamptz not null default now(),
  primary key (code, utilisateur),
  unique (code, numero)
);
comment on table public.pf_membres is 'Qui est dans quel salon de Portefaix (l''hôte porte le numéro 1).';

create table public.pf_signaux (
  id bigint generated always as identity primary key,
  code text not null references public.pf_salons (code) on delete cascade,
  de int not null,
  vers int not null,
  donnees jsonb not null,
  cree_le timestamptz not null default now()
);
comment on table public.pf_signaux is 'Messages de mise en relation (WebRTC) entre deux membres d''un salon de Portefaix.';

create index pf_salons_hote on public.pf_salons (hote);
create index pf_membres_utilisateur on public.pf_membres (utilisateur);
create index pf_signaux_pour on public.pf_signaux (code, vers, id);

alter table public.pf_salons enable row level security;
alter table public.pf_membres enable row level security;
alter table public.pf_signaux enable row level security;
revoke all on public.pf_salons, public.pf_membres, public.pf_signaux from anon, authenticated;

-- un pseudo propre : sans caractère de contrôle ni chevron, 16 lettres au plus
create function public.pf_pseudo(p text) returns text
language sql immutable set search_path = '' as $$
  select coalesce(nullif(btrim(left(btrim(regexp_replace(coalesce(p, ''), '[[:cntrl:]<>]', '', 'g')), 16)), ''), 'Porteur')
$$;

-- ouvrir un salon : rend son code (cinq lettres ou chiffres, sans ceux qui se confondent). On n'est que dans un salon à la fois.
create function public.pf_salon_creer(p_pseudo text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  moi uuid := auth.uid();
  c text;
begin
  if moi is null then return jsonb_build_object('erreur', 'connexion'); end if;
  delete from public.pf_salons where vu_le < now() - interval '15 minutes' or cree_le < now() - interval '6 hours';
  delete from public.pf_salons where hote = moi;
  delete from public.pf_membres where utilisateur = moi;
  if (select count(*) from public.pf_salons) >= 200 then return jsonb_build_object('erreur', 'plein'); end if;
  for essai in 1..20 loop
    c := (select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 1 + floor(random() * 32)::int, 1), '') from generate_series(1, 5));
    begin
      insert into public.pf_salons (code, hote) values (c, moi);
      exit;
    exception when unique_violation then
      c := null;
    end;
  end loop;
  if c is null then return jsonb_build_object('erreur', 'plein'); end if;
  insert into public.pf_membres (code, utilisateur, numero, pseudo) values (c, moi, 1, public.pf_pseudo(p_pseudo));
  return jsonb_build_object('code', c, 'numero', 1);
end $$;

-- entrer dans un salon par son code : rend son numéro. Six porteurs au plus ; on n'entre pas dans une nuit commencée.
create function public.pf_salon_rejoindre(p_code text, p_pseudo text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  moi uuid := auth.uid();
  c text := upper(btrim(coalesce(p_code, '')));
  s public.pf_salons;
  n int;
begin
  if moi is null then return jsonb_build_object('erreur', 'connexion'); end if;
  select * into s from public.pf_salons where code = c for update;
  if not found or s.vu_le < now() - interval '15 minutes' then return jsonb_build_object('erreur', 'introuvable'); end if;
  select numero into n from public.pf_membres where code = c and utilisateur = moi;
  if found then
    update public.pf_membres set pseudo = public.pf_pseudo(p_pseudo), vu_le = now() where code = c and utilisateur = moi;
    return jsonb_build_object('code', c, 'numero', n);
  end if;
  if s.etat <> 'ouvert' then return jsonb_build_object('erreur', 'parti'); end if;
  if (select count(*) from public.pf_membres where code = c) >= 6 then return jsonb_build_object('erreur', 'complet'); end if;
  delete from public.pf_salons where hote = moi;
  delete from public.pf_membres where utilisateur = moi;
  n := (select max(numero) + 1 from public.pf_membres where code = c);
  insert into public.pf_membres (code, utilisateur, numero, pseudo) values (c, moi, n, public.pf_pseudo(p_pseudo));
  return jsonb_build_object('code', c, 'numero', n);
end $$;

-- où en est mon salon : qui y est, et les messages qu'on m'a laissés depuis le dernier que j'ai lu. Dit aussi que je suis toujours là.
create function public.pf_salon_etat(p_code text, p_apres bigint default 0) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  moi uuid := auth.uid();
  c text := upper(btrim(coalesce(p_code, '')));
  n int;
  e text;
begin
  if moi is null then return jsonb_build_object('erreur', 'connexion'); end if;
  update public.pf_membres set vu_le = now() where code = c and utilisateur = moi returning numero into n;
  if n is null then return jsonb_build_object('erreur', 'dehors'); end if;
  if n = 1 then update public.pf_salons set vu_le = now() where code = c; end if;
  select etat into e from public.pf_salons where code = c;
  return jsonb_build_object('code', c, 'etat', e, 'numero', n,
    'membres', (select jsonb_agg(jsonb_build_object('numero', numero, 'pseudo', pseudo) order by numero) from public.pf_membres where code = c),
    'signaux', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'de', de, 'donnees', donnees) order by id)
      from public.pf_signaux where code = c and vers = n and id > coalesce(p_apres, 0)), '[]'::jsonb));
end $$;

-- laisser un message de mise en relation à un autre membre de mon salon
create function public.pf_salon_signal(p_code text, p_vers int, p_donnees jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  moi uuid := auth.uid();
  c text := upper(btrim(coalesce(p_code, '')));
  n int;
begin
  if moi is null then return jsonb_build_object('erreur', 'connexion'); end if;
  select numero into n from public.pf_membres where code = c and utilisateur = moi;
  if n is null then return jsonb_build_object('erreur', 'dehors'); end if;
  if p_donnees is null or pg_column_size(p_donnees) > 8000 or (select count(*) from public.pf_signaux where code = c) >= 800 then
    return jsonb_build_object('erreur', 'trop');
  end if;
  if not exists (select 1 from public.pf_membres where code = c and numero = p_vers) or p_vers = n then
    return jsonb_build_object('erreur', 'destinataire');
  end if;
  insert into public.pf_signaux (code, de, vers, donnees) values (c, n, p_vers, p_donnees);
  return jsonb_build_object('ok', true);
end $$;

-- l'hôte lance la nuit : plus personne n'entre
create function public.pf_salon_partir(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  moi uuid := auth.uid();
begin
  if moi is null then return jsonb_build_object('erreur', 'connexion'); end if;
  update public.pf_salons set etat = 'parti', vu_le = now() where code = upper(btrim(coalesce(p_code, ''))) and hote = moi;
  return jsonb_build_object('ok', found);
end $$;

-- quitter son salon ; si c'est l'hôte qui part, le salon ferme
create function public.pf_salon_quitter(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  moi uuid := auth.uid();
  c text := upper(btrim(coalesce(p_code, '')));
  n int;
begin
  if moi is null then return jsonb_build_object('erreur', 'connexion'); end if;
  delete from public.pf_salons where code = c and hote = moi;
  if found then return jsonb_build_object('ok', true); end if;
  delete from public.pf_membres where code = c and utilisateur = moi returning numero into n;
  if n is not null then delete from public.pf_signaux where code = c and (de = n or vers = n); end if;
  return jsonb_build_object('ok', n is not null);
end $$;

-- seuls les comptes connectés appellent ces fonctions
revoke all on function public.pf_pseudo(text), public.pf_salon_creer(text), public.pf_salon_rejoindre(text, text), public.pf_salon_etat(text, bigint),
  public.pf_salon_signal(text, int, jsonb), public.pf_salon_partir(text), public.pf_salon_quitter(text) from public, anon;
grant execute on function public.pf_salon_creer(text), public.pf_salon_rejoindre(text, text), public.pf_salon_etat(text, bigint),
  public.pf_salon_signal(text, int, jsonb), public.pf_salon_partir(text), public.pf_salon_quitter(text) to authenticated;

-- Pour tout retirer :
--   drop function public.pf_salon_creer(text), public.pf_salon_rejoindre(text, text), public.pf_salon_etat(text, bigint),
--     public.pf_salon_signal(text, int, jsonb), public.pf_salon_partir(text), public.pf_salon_quitter(text), public.pf_pseudo(text);
--   drop table public.pf_signaux, public.pf_membres, public.pf_salons;
