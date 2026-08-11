-- Real-world courts aren't always uniform: a club running mostly doubles
-- might dedicate one court to singles for stronger players, or vice versa.
-- Null means "inherit the game's overall isDoubles setting" (today's
-- behavior, unchanged for every existing court); true/false forces that
-- one court to singles/doubles regardless of the game default.
alter table courts add column singles_override boolean;
