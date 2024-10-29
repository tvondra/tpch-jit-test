#!/usr/bin/bash

set -e

VERSION=$1
SCALE=$2
WORKERS=$3
DATADIR=$4
RESULTS=$5
RUNS=$6

for q in $(seq 1 22); do

	for r in $(seq 1 $RUNS); do

			pg_ctl -D $DATADIR -l pg.log -w restart
			sudo ./drop-caches.sh

			sed 's/explain /explain (summary off, costs off)/' explain/$q.sql > plan.sql

			psql test-$SCALE > plan.log <<EOF
set work_mem = '32MB';
set max_parallel_workers_per_gather = $WORKERS;
set statement_timeout = 3600000;
\i plan.sql
EOF

			h=$(md5sum plan.log | awk '{print $1}')
			cat plan.log >> plans.log

			echo "query $q run $r" >> explains.log

			psql test-$SCALE >> explains.log <<EOF
set work_mem = '32MB';
set max_parallel_workers_per_gather = $WORKERS;
set statement_timeout = 3600000;
\i explain/$q.sql
EOF

			s=$(psql -t -A test-$SCALE -c "SELECT extract(epoch from now())")

			psql test-$SCALE > /dev/null <<EOF
set work_mem = '32MB';
set max_parallel_workers_per_gather = $WORKERS;
set statement_timeout = 3600000;
\i queries/$q.sql
EOF

			t=$(psql -t -A test-$SCALE -c "SELECT (extract(epoch from now()) - $s) * 1000")

			echo "tpch" $VERSION $SCALE $WORKERS $q $r uncached $h $t >> $RESULTS

                        s=$(psql -t -A test-$SCALE -c "SELECT extract(epoch from now())")

                        psql test-$SCALE > /dev/null <<EOF
set work_mem = '32MB';
set max_parallel_workers_per_gather = $WORKERS;
set statement_timeout = 1800000;
\i queries/$q.sql
EOF

                        t=$(psql -t -A test-$SCALE -c "SELECT (extract(epoch from now()) - $s) * 1000")

                        echo "tpch" $VERSION $SCALE $WORKERS $q $r cached $h $t >> $RESULTS

	done

done
