#!/usr/bin/env zsh
set -euo pipefail -o glob
#shellcheck disable=1091
source "$SCRIPT_ROOT/data/shared/local_env.sh"
cd "$WORK_LOG_DIR" || exit 1

FORMAT='%d: %w/%q | %t %n'
START='begin'
END='today'
AGGREGATE='never' # day week month year never


declare -A worked periods quota basequota edits editnotes
begin=( ***/*.md([1]:t:r) )
begin="${(@)begin[1]}"
declare -i nday=0 nyear="$(date +%Y)"
cache=${XDG_CACHE:-"$HOME/.cache"}/holidays.cache
definition='./hours+holidays+vacation.txt'
holidays="https://commenthol.github.io/date-holidays/#en/{}/$WORK_HOLIDAY_LOCATION"
[ -e "$cache" ] || :>>"$cache"

while [ "$#" != 0 ]; do case "$1"; in
    -f|--format) FORMAT="$2"; shift;;
    -x|--csv)    FORMAT='%d;%0w;%0q;%0t;%n';AGGREGATE='week';;
    -s|--start)  START="$2"; shift;;
    -e|--end)    END="$2"; shift;;
    -a|--aggregate) case "$2" in
        day|week|month|year|never) AGGREGATE="$2"; esac; shift;;
    -d|--directory) cd "$2"||exit 1;shift;;
    -h|--help) less -F << EOF
Work with worktime slowly but feature-ly
-a  --aggregate
    select what to aggregate on, supported: day, week, month, year, never
-d  --directory  set work log directory
-e  --end        set end
-f  --format
    set supported format
    %w  %q  %o  %t   aggregated {work, quota, over} time, total overtime
    %0w %0q %0o %0t  padded with zeros and ending with ':00'
    %d               aggregated type prefix
    %n               aggregated edit notes
-s  --start      set start, special value “begin”
-x  --csv        use format '%d;%0w;%0q;%0t;%n' and aggregate on weeks

Time worked:
 All dates are expected to be in ISO 8601 full date format, i.e. yyyy-mm-dd,
 all times also use ISO 8601, i.e. [h]h:mm.

 The script searches recursively for markdown files containing the timestamps
 to process.
 The files are expected to be called \`<date>.md\` where <date> is the day the
 the timestamps apply. The script will search for the timestamps in the first
 level-zero list bullet point. The bullet point can be multi-line.
 That line may contain the following patters:
  Timestamps use the following format:
   <start_time> "-" <end_time>
  E.g.
   10:00-12:00, 13:37-17:00, 23:00-04:00
  All time stamps are accumulated to calculated the worked time.

  Every number in parenthesis is considered a break definition.
  Breaks use the following format:
   [ <hour> "h" ] <minute> "m"
  E.g.
   ( 30m and 1h30m and 75m )
  Specifying hours is optional and the same as specifying \`60m\`. The break will
  be deducted from the worked time.

  Everything else is considered a comment and ignored.
  An example file:
   * Worked from 17:00-20:00, 22:00-01:00 (with a 7m and a 3m break) and then
     went to bed after working from 7:00-9:00 in the morning
     * I should not work from 22:00-01:00 anymore # ignored
   * I heard from a friend that they work from 09:-17:00 # ignored

Defining quota hours and edits:
 The script searches for a hour definition file called
 '$definition' in the work log directory.
 This file has the following syntax:
  All dates are expected to be in ISO 8601 full date format, i.e. yyyy-mm-dd

  Lines starting with \`#\` define expected weekly quota in hours in the
  following format:
   "#" <hours> "*" <start_date>
  where <hours> is a positive integer and <start_date> is a date.
  E.g.
   # 40 * 2012-12-21
  The start date defines the first date the hourly change shall be applied. It
  can be an arbitrary day, as long as it is strictly later than start dates
  defined in prior quota definitions.
  The hours define the weekly expected quota.

  Lines starting with \`-\` or  \`+\` define quota edits.
  They have the following format
   <"+"|"-"> <hours> <note> <date(s)>[<modifier>]
  where the mandatory sign is either a literal \`+\` or \`-\`, <hours> is a number
  which allows for fractions, <note> is an arbitrary string which does not
  contain any numbers, <date(s)> being a comma separated list of dates and
  <modifier> being a single optional character.
  E.g.
   -40   vacation 2021-12-21--2022-01-06,2022-02-21!
   +10.5 payout   2020-01-01
  The edits appy to the expected the quota, thus \`-\` removes from it and \`+\`
  adds to it.
  By default negative hours have a documentation purpose only; the script will
  set the quota for that day to zero. This behavior can be changed with the
  modifier.
  The list of dates define when the edit appies. The edit will be done for each
  matching day! Multiple dates can be specified by delimiting them with \`,\`
  (with no sourrounding whitespace). A range of dates can be specified by
  delimiting a start and end date with \`--\`.
  The modifier is a single optional character:
   A: “apply”, actually use the hours to substract from the quota. The quota
      cannot become negative by this edit.
   !: “force apply”, same as \`A\` but allow the quota to become negative
      by this edit; use with caution!
  It applies to every matching day, so it should be used with a single day at a
  time.
  Entries without a date are disencouraged and will be applied separately at the
  end of the output.

  Everything not machting or after these two line patters will be treated as
  comments and ignored.

 The script will automatically add missing holidays to the definition file.
EOF
        exit;;
    -*) echo "Unknown option: $1">&2;exit 1;;
    *) cd "$1"||exit 1;;
esac;shift;done

START="$(date -d"${START//begin/$begin}" +%s)"
END="$(date -d"${END//begin/$begin}" +%s)"

for (( year="${begin%-*-*}"; year <= nyear; ++year )); do
    grep -q "^$year" "$cache" || break
done

if (( $year <= $nyear )); then
    echo "Caching holidays from $year to $nyear..." >&2
    pacman -Qq selenium-manager python-selenium &>/dev/null || paru -Sy selenium-manager python-selenium
    python - "$year" "$nyear" >> "$cache" << EOF
from sys import argv
from selenium import webdriver
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.firefox.service import Service

url= '$holidays'

o = Options()
o.add_argument('-headless')

with webdriver.Firefox(options=o, service=Service(log_output='/tmp/geckodriver.log')) as driv:
    for year in range(int(argv[1]), int(argv[2])+1):
        driv.get(url.format(year))

        for row in driv.find_elements(By.XPATH, '//tr')[1:]:
            cells = row.find_elements(By.XPATH, './/td')
            if (cells[5].text == 'public'):
                print(f"{cells[2].text},{cells[4].text.lower()}")
EOF
fi

sed '/^\s*[^#]/d;s/#\s*\([0-9]*\)\s*\*\s*\(\S*\).*/date -d\2 "+%s $((\1*60*60\/5))"/;e' "$definition" |
    while read k v; do periods[$k]=$v; done
sed -e '/^\s*\([^-+]\|$\)/d;s/\s*\([+-]\)\s*\([0-9.]*\)\([^0-9]*\)\([-0-9,]*\)\([A!]\?\).*/\4@\5\1\2@\3/;s/@+/@A/;s/@-/@?-/;s/\([-0-9]*\)--\([-0-9]*\)/+\1#\2 1day-1sec/g;s/\(^\|,\)\([0-9]\{4\}-[0-9][0-9]-[0-9][0-9]\)/+\2#\2 1day-1sec/g;s/\([+#]\)\([0-9]*-[^+#@]*\)/\1$(date -d"\2" +%s)/g;s/@\(.\)\([-+0-9.]*\)[^@]*@\s*\(.*\)\s*$/))@\1$(bc <<< "\2*60*60")@\3"/;s/+\$/||$/g;s/#/<=day\&\&day<=/g;s/^||/echo "((/;s/^))@\([^)]*)\)/echo "false \1@\1/;e' -e ';s/\.0@/@/g;s/\s*$//' "$definition" |
    while IFS=@ read k t n; do edits[$k]="$t"; editnotes[$k]="$n"; done

case "$AGGREGATE" in
    never)
        aggregate_on=0
        d_format='%F'
        ;;
    day)
        aggregate_on=1
        d_format='%F'
        ;;
    week)
        aggregate_on='%-u'
        d_format='%F (%V)'
        ;;
    month)
        aggregate_on='%-d'
        d_format='%4Y-%m'
        ;;
    year)
        aggregate_on='%-j'
        d_format='%4Y'
        ;;
    *)
        echo "Unknown aggregation: $AGGREGATE" >&2 && exit 1
esac
FORMAT=${FORMAT//'%d'/'%1$s'}
FORMAT=${FORMAT//'%w'/'%2$1s%3$4d:%4$02d'}
FORMAT=${FORMAT//'%0w'/'%2$1s%3$04d:%4$02d:00'}
FORMAT=${FORMAT//'%W'/'%5$09d'}
FORMAT=${FORMAT//'%q'/'%6$1s%7$4d:%8$02d'}
FORMAT=${FORMAT//'%0q'/'%6$1s%7$04d:%8$02d:00'}
FORMAT=${FORMAT//'%Q'/'%9$09d'}
FORMAT=${FORMAT//'%o'/'%10$1s%11$4d:%12$02d'}
FORMAT=${FORMAT//'%o'/'%10$1s%11$04d:%12$02d:00'}
FORMAT=${FORMAT//'%O'/'%13$09d'}
FORMAT=${FORMAT//'%t'/'%14$1s%15$4d:%16$02d'}
FORMAT=${FORMAT//'%0t'/'%14$1s%15$04d:%16$02d:00'}
FORMAT=${FORMAT//'%T'/'%17$09d'}
FORMAT=${FORMAT//'%n'/'%18$s'}

declare -i aworked=0 aquota=0 aover=0 tworked=0 tquota=0 tover=0
last_d="$(date -d$begin +"$d_format")"
anotes=''
anoteedit=''


print_state() {
    ((day >= START)) && printf "$FORMAT"'\n%19$s' "$last_d" \
        "${(M)aworked[1]:#-}" "${$((aworked/3600))#-}" "${$((aworked%3600/60))#-}" "$aworked" \
        "${(M)aquota[1]:#-}"  "${$((aquota/3600))#-}"  "${$((aquota%3600/60))#-}"  "$aquota" \
        "${(M)aover[1]:#-}"   "${$((aover/3600))#-}"   "${$((aover%3600/60))#-}"   "$aover" \
        "${(M)tover[1]:#-}"   "${$((tover/3600))#-}"   "${$((tover%3600/60))#-}"   "$tover" \
        "${anotes#, }" ''  || true
}

[ ! -f "$definition" ] && echo 'Missing definition file!' >&2 && exit 1

while true; do
    day=$(date -d"$begin ${nday}day" +%s)
    (( day > END )) && break
    dfile="$(date -d"@$day" +%Y-%m/%F.md)"
    dformatted="$(date -I -d"@$day")"
    # worked
    if [ -e "$dfile" ]; then
        worked[$day]=$(sed -sne '/^\s*[^* ]/{H;$!d};/^*/{${x;/^*/x}};x;/^*/{s/\n\s*/ /g;s/[^0-9(]*//;/^$/be;:b;s/(\([^)]*\))\([^(]*\)(/\2(\1/g;tb;s/\(([^)]*)\)\(.*\)/\2 \1/;s/[^0-9(]*\([0-9]\+\)\s*:\s*\([0-9]\+\)\s*-\s*\([0-9]\+\)\s*:\s*\([0-9]\+\)[^0-9(]*/+@\1:\2@\3:\4\n/g;s/\([0-9]\+\)\s*min\(utes\)\?/\1m/g;s/1h/60m /g;:l;s/([^0-9]*\([0-9]\+\)/-@00:00@\1min 00:00\n(/;tl;s/(.*//g;s/\n$//;/^[^+-]/M{s/[+-]@.*\n\?//gM;w/dev/stderr' -e 'q1};p;:e;N;$!be;d;};' "$dfile"|while IFS=@ read -r S A B;do echo "$S$(($(date +%s -d"$B")-$(date +%s -d"$A")))";done|tr -d '\n'|sed 's/+-/+(60*60*24)-/g;s/^+//;s/$/\n/'|bc||echo error)
    fi
    worked[$day]=${worked[$day]:-0}
    [ "${worked[$day]}" = error ] && echo "Invalid format in $dformatted!" && exit 1
    # quota
    if (($(date -d@$day +%u) > 5)) ;then
        quota[$day]=0
        basequota[$day]=0
    else
        for period in ${(kn)periods}; do
            if ((period <= day)); then
                quota[$day]=${periods[$period]}
                basequota[$day]=${periods[$period]}
            else
                break
            fi
        done
    fi
    for edit in ${(k)edits}; do
        if eval "${edit:-false}"; then
            val=${edits[$edit]}
            anoteedit="$edit"
            case "$val" in
                \?*)
                    edits[$edit]=${val[1]}$((${val#?}+$quota[$day]))
                    quota[$day]=0
                    ;;
                !*)
                    quota[$day]=$((${val#!}+$quota[$day]))
                    ;;
                A*)
                    quota[$day]=$((${val#A}+$quota[$day]))
                    if ((quota[$day] < 0)); then
                        quota[$day]=0
                    fi
                    ;;
                *)
                    echo "cannot determine edit type!: $val" >&2 && exit 1
            esac
            break
        fi
    done
    if ((quota[$day] > 0)) && grep -q "^$dformatted" "$cache"; then
        quota[$day]=0
        echo "Undocumented holiday: $dformatted!" >&2
        note="${$(grep "^$dformatted" "$cache")#*,}"
        LC_NUMERIC=C printf '-%3.2f %-20s%s\n' \
            "$(($basequota[$day]/3600.))" \
            "$note" \
            "$dformatted" >> "$definition"
                    anotes="${${(M)anotes:#*$note*}:-$anotes, $note}"
    fi
    if [ "$(date -d@$day +$aggregate_on)" = 1 ]; then
        print_state
        last_d="$(date -d@$day +"$d_format")"
        aworked=0; aquota=0; aover=0; anotes=''
    fi
    aworked+=worked[$day]
    aquota+=quota[$day]
    aover+=$((worked[$day]-quota[$day]))
    tworked+=worked[$day]
    tquota+=quota[$day]
    tover+=$((worked[$day]-quota[$day]))
    [ -n "${anoteedit}" ] && anotes="${${(M)anotes:#*${editnotes[$edit]}*}:-$anotes, ${editnotes[$edit]}}"
    anoteedit=''
    nday=$((nday+1))
done
[ $AGGREGATE = 'never' ] && anotes=''
print_state
last_d="$(printf "%${#last_d}s" 'edit?')"
if [ $AGGREGATE != 'never' ]; then
    aworked=0; aquota=0; aover=0
fi
for k in ${(Mk)edits:#false*}; do
    val=${edits[$k]}
    case "$val" in
        A*|\?*|!*)
            aquota=$((${val#?}+$aquota))
            aover=$((${val#?}*-1+$aover))
            tquota=$((${val#?}+$tquota))
            tover=$((${val#?}*-1+$tover))
            anotes="${editnotes[$k]}"
            ;;
        *)
            echo "cannot determine edit type!: $val" >&2 && exit 1
    esac
    print_state
done
