# bash-scripts

Assorted bash scripts licensed under [CC BY-SA](https://creativecommons.org/licenses/by-sa/4.0/), share alike with attribution.

**Scripts**
* [stats.bash](#statsbash) to capture host performance stats

## stats.bash

I started with [Brendan Gregg's Linux Performance Analysis in 60 Seconds](https://medium.com/netflix-techblog/linux-performance-analysis-in-60-000-milliseconds-accc10403c55). I wanted a script that would run non-interactively (possibly from cron), and could write those values to a gnuplot-compatible text file. I use this script when I don't know where to start chasing a performance problem; afterwards, I should know what might be and what is not the problem.

This should get you started with [`gnuplot`](http://gnuplot.sourceforge.net/index.html) although I haven't tested it yet:
```
$ gnuplot
gnuplot> set grid
gnuplot> set xdata time
gnuplot> set timefmt "%s"
gnuplot> set format x "%Y-%m-%d-%H:%M"
gnuplot> plot "stats.tsv" using 1:2 title "load1min" with linespoint, "stats.tsv" using 1:3 title "load5min" w lp, "stats.tsv" using 1:4 title "load15min" w lp
```

If you want to view graphs in [Grafana](https://grafana.com/) (I love Grafana!) instead of gnuplot, send the values to a carbon process (the part of [graphite-web](https://github.com/graphite-project/graphite-web) that writes the metrics; whisper is the time-series database that Grafana can read using its graphite datasource). Using netcat, nc, or socat should be quick. Also not tested yet:
```
PORT=2003
SERVER=graphite
# stdout display with field numbers, just for your reference
sed -n 1p stats.tsv | sed 's/^\# //g' | tr '\t' '\n' | nl
# Bash array:
declare -a NAMEARRAY=( $(sed -n 1p stats.tsv | sed 's/^\# //g') )
# note: zero is the index of the first element in a bash array
# also note: one is the first index to awk
declare -i DEBUG=1
sed 1d stats.tsv | sed 's/^\# //g' | while read LINE
do
  DATESTAMP=$(echo "${LINE}" | awk '{ print $1 }')
  for ((i = 1; i < ${#NAMEARRAY[@]}; i++))
  do
    NAME="${NAMEARRAY[i]}"
    VALUE=$(echo "${LINE}" | awk '{ print $(i+1) }')
    if (( DEBUG )); then echo "Name $i: ${NAMEARRAY[i]} (should be ${NAME}) with Value: ${VALUE}"; fi
    echo "${NAME} ${VALUE} ${DATESTAMP}" | netcat ${SERVER} ${PORT}
  done
done
```
