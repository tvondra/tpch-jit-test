#!/usr/bin/bash -x

set -e

LABEL=$1
PATH_OLD=$PATH
DATADIR=/mnt/pgdata/data
PSQL=/mnt/data/builds/18/bin/psql

TS=$(date +%Y%m%d-%H%M%S)
LOGDIR=$TS-$LABEL/logs
RESULTS=$TS-$LABEL/results

RUNS=5

mkdir -p $LOGDIR
mkdir -p $RESULTS

killall -9 postgres || true
rm -Rf $DATADIR

for s in 1 10; do

	for v in 18-jit-on 18-no-jit 18-jit-off; do

		for w in 0 4; do

			killall -9 postgres || true

			PATH=/mnt/data/builds/$v/bin:$PATH_OLD

			if [ ! -d "$DATADIR" ]; then
				initdb -D $DATADIR > $LOGDIR/initdb-$v-$s.log 2>&1
			fi

			rm -f $DATADIR/postgresql.auto.conf

			echo "shared_buffers = 262143" >> $DATADIR/postgresql.auto.conf
			echo "checkpoint_timeout = 1800" >> $DATADIR/postgresql.auto.conf
			echo "max_connections = 1000" >> $DATADIR/postgresql.auto.conf
			echo "work_mem = '32768'" >> $DATADIR/postgresql.auto.conf

			echo "random_page_cost = 2" >> $DATADIR/postgresql.auto.conf

			echo "effective_io_concurrency = 54" >> $DATADIR/postgresql.auto.conf

			echo "max_wal_size = '128GB'" >> $DATADIR/postgresql.auto.conf
			echo "min_wal_size = '32GB'" >> $DATADIR/postgresql.auto.conf

			echo "cpu_index_tuple_cost = 0.005" >> $DATADIR/postgresql.auto.conf
			echo "default_statistics_target = 100" >> $DATADIR/postgresql.auto.conf
			echo "effective_cache_size = 16384" >> $DATADIR/postgresql.auto.conf
			echo "maintenance_work_mem = 65536" >> $DATADIR/postgresql.auto.conf
			echo "wal_buffers = 512" >> $DATADIR/postgresql.auto.conf
			echo "work_mem = 4096" >> $DATADIR/postgresql.auto.conf

			if [ "$v" == "18-jit-on" ]; then
				echo "jit = on" >> $DATADIR/postgresql.auto.conf
			else
				echo "jit = off" >> $DATADIR/postgresql.auto.conf
			fi

			pg_ctl -D $DATADIR -l $LOGDIR/pg-$v-$s-$w.log -w start

			sleep 1

			c=$(psql postgres -t -A -c "select 1 from pg_database where datname = 'test-$s'")

			if [ "$c" != "1" ]; then

				createdb "test-$s"

				a=$(date +%s)

				$PSQL -e "test-$s" > $LOGDIR/load-$v-$s-$w.log 2>&1 <<EOF
set max_parallel_maintenance_workers = $w;
set max_parallel_workers_per_gather = $w;
set maintenance_work_mem = 262144;
\timing on
\i load-$s.sql
EOF

				b=$(date +%s)

				$PSQL -e "test-$s" >> $LOGDIR/load-$v-$s-$w.log 2>&1 <<EOF
set max_parallel_maintenance_workers = $w;
set max_parallel_workers_per_gather = $w;
set maintenance_work_mem = 262144;
\timing on
\i ios.sql
EOF

				c=$(date +%s)

				$PSQL -e "test-$s" > $LOGDIR/fkeys-$v-$s-$w.log 2>&1 <<EOF
set max_parallel_maintenance_workers = $w;
set max_parallel_workers_per_gather = $w;
set maintenance_work_mem = 262144;
\timing on
\i foreign-keys.sql
EOF

				d=$(date +%s)

				echo $v $s $w $((b-a)) $((c-b)) $((d-c)) >> load.csv 2>&1

			fi

			$PSQL "test-$s" -c "select * from pg_settings" > $LOGDIR/settings-$v-$s-$w.log 2>&1

			rm -f explains.log plans.log

			./run-queries-jit.sh $v $s $w $DATADIR results.csv $RUNS
			mv explains.log $LOGDIR/explains-$v-$s-$w.log
			mv plans.log $LOGDIR/plans-$v-$s-$w.log

			./run-analyze-jit.sh $v $s $w $DATADIR results.csv
			mv explains.log $LOGDIR/analyze-$v-$s-$w.log

			pg_ctl -D $DATADIR -w stop

			sleep 1

		done

	done

done
