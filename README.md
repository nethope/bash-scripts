# bash-scripts

Assorted bash scripts licensed under [CC BY-SA](https://creativecommons.org/licenses/by-sa/4.0/), share alike with attribution.

**Scripts**
* [stats.bash](#stats) to capture host performance stats

## <a name="stats">stats.bash</a>

I started with [Brendan Gregg's Linux Performance Analysis in 60 Seconds](https://medium.com/netflix-techblog/linux-performance-analysis-in-60-000-milliseconds-accc10403c55). I wanted a script that would run non-interactively - possibly from cron, and could write those metric values to a gnuplot-compatible text file. I use this script when I'm chasing a performance problem, and I don't know where to start: afterwards, I should know what might be and what is not the problem.

If you want to view graphs in Grafana (I love Grafana!) instead of gnuplot, use the whisper tools to send the values to carbon.

(I will include examples later, after testing.)
