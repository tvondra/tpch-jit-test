-- using 1583427054 as a seed to the RNG


explain select
	s_name,
	s_address
from
	supplier,
	nation
where
	s_suppkey in (
		select
			ps_suppkey
		from
			partsupp,
			(
				select
					l_partkey as agg_partkey,
					l_suppkey as agg_suppkey,
					0.5 * sum(l_quantity) AS agg_quantity
				from
					lineitem
				where
					l_shipdate >= date '1996-01-01'
					and l_shipdate < date '1997-01-01'
				group by
					l_partkey,
					l_suppkey
			) agg_lineitem
		where
			agg_partkey = ps_partkey
			and agg_suppkey = ps_suppkey
			and ps_partkey in (
				select
					p_partkey
				from
					part
				where
					p_name like 'olive%'
			)
			and ps_availqty > agg_quantity
	)
	and s_nationkey = n_nationkey
	and n_name = 'IRAQ'
order by
	s_name
LIMIT 1;
