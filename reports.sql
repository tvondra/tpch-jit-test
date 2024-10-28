create table tpch (test text, build text, scale int, workers int, query int, run int, caching text, plan text, timing double precision);

select
  scale, workers, caching, count(*) AS cnt,
  sum(timing_no_jit) as timing_no_jit,
  sum(timing_jit_off) as timing_jit_off,
  sum(timing_jit_on) as timing_jit_on,
  (100.0 * sum(timing_jit_off) / sum(timing_no_jit))::int AS pct_jit_off,
  (100.0 * sum(timing_jit_on) / sum(timing_no_jit))::int AS pct_jit_on
from (
  select
    scale, workers, caching, query,
    count(*) filter (where build = '18-no-jit') AS cnt_no_jit,
    count(*) filter (where build = '18-jit-off') AS cnt_jit_off,
    count(*) filter (where build = '18-jit-on') AS cnt_jit_on,
    min(substr(plan, 1, 8)) filter (where build = '18-no-jit') as plan_no_jit,
    min(substr(plan, 1, 8)) filter (where build = '18-jit-off') as plan_jit_off,
    min(substr(plan, 1, 8)) filter (where build = '18-jit-on') as plan_jit_on,
    (avg(timing) filter (where build = '18-no-jit'))::int as  timing_no_jit,
    (avg(timing) filter (where build = '18-jit-off'))::int as timing_jit_off,
    (avg(timing) filter (where build = '18-jit-on'))::int as timing_jit_on
  from tpch group by 1, 2, 3, 4
  order by 1, 2, 3, 4
) foo where plan_no_jit = plan_jit_off and plan_jit_off = plan_jit_on group by 1, 2, 3
order by 1, 2, 3;

select * from (select
  scale, workers, caching, query,
  count(*) filter (where build = '18-no-jit') AS cnt_no_jit,
  count(*) filter (where build = '18-jit-off') AS cnt_jit_off,
  count(*) filter (where build = '18-jit-on') AS cnt_jit_on,
  min(substr(plan, 1, 8)) filter (where build = '18-no-jit') as plan_no_jit,
  min(substr(plan, 1, 8)) filter (where build = '18-jit-off') as plan_jit_off,
  min(substr(plan, 1, 8)) filter (where build = '18-jit-on') as plan_jit_on,
  (avg(timing) filter (where build = '18-no-jit'))::int as  timing_no_jit,
  (avg(timing) filter (where build = '18-jit-off'))::int as timing_jit_off,
  (avg(timing) filter (where build = '18-jit-on'))::int as timing_jit_on,
  (100.0 * (avg(timing) filter (where build = '18-jit-off')) / (avg(timing) filter (where build = '18-no-jit')))::int as pct_of,
  (100.0 * (avg(timing) filter (where build = '18-jit-on')) / (avg(timing) filter (where build = '18-no-jit')))::int as pct_on
from tpch group by 1, 2, 3, 4
order by 1, 2, 3, 4) foo;
