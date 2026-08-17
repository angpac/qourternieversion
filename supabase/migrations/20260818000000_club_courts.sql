-- Number of courts available at a club, set by the owner when creating it
-- (replaces picking sports up front in the Create a Club flow).
alter table clubs add column courts integer not null default 0;
