#!/bin/bash

html_body=""

CRITICAL_REMAINING_DAY=60

DOMAIN_LIST_FILE=$1
OUTPUT_HTML_FILE=$2
V_LAST_ROW_DAYS_REMAIN=0
V_DOMAIN_EXIST=0

DEBUG=1
############ Functions #################################

function debug_print() {
   if [ "$DEBUG" -eq 1 ];
   then
      OUTPUT=$1
      echo $OUTPUT
   fi 
}

function help_print() {
  echo "list_domain_expire_date.sh"
  echo "DESCRIPTION: "
  echo "Reads a file containing the domain names, gets the expiration dates of those domains; creates a html report;"
  echo "marks rows if remaining times to expire gets below $CRITICAL_REMAINING_DAY days"
  echo "USAGE: sh list_domain_expire_date.sh \$arg1 [\$arg2]"
  echo "  \$arg1= File containing list of domain names"
  echo "  Example:"
  echo "    yahoo.com "
  echo "    google.com "
  echo "  \$arg2= Path to create html report; Default list_domain_expire_dates.html"
  exit 1
 
}

function generate_html_body {
  domain=$1
  expire_date=$2
  days_remain=$3
  if [ $days_remain -ge 0 ]; then
	  if [ $days_remain -le $CRITICAL_REMAINING_DAY ]; then
	    v_critical_style_sheet=`echo "style=\"color: #fff; background: red;\""`
	  else
	   v_critical_style_sheet=""
	  fi
	  
	  row=`echo "<tr "$v_critical_style_sheet" ><td>"$domain" </td><td align=\"center\"> "$expire_date"</td><td align=\"center\">"$days_remain"</td> \n "`
	  if [ $days_remain -ge $V_LAST_ROW_DAYS_REMAIN ]; then
	    html_body=`echo $html_body $row`
	  else
	    html_body=`echo $row $html_body`
	  fi  
	  V_LAST_ROW_DAYS_REMAIN=$days_remain
  else
    #Domain not exists
    v_critical_style_sheet=`echo "style=\"background: #FFFF00;\""`
    row=`echo "<tr "$v_critical_style_sheet" ><td>"$domain" </td><td align=\"center\"> "Invalid domain name"</td><td align=\"center\">"n/a"</td> \n "`
    html_body=`echo $html_body $row`
  fi #if [ $days_remain -ge 0 ]; then
}   


function check_domain_exists() {

  ping -c1 $1 >> /dev/null

  if [ $? == 2 ]; then
    debug_print "$1 does not exist."
    V_DOMAIN_EXIST=0
  else
    debug_print "$1 exists."
    V_DOMAIN_EXIST=1
  fi
}

######## Main section ###############################

if [ -z "$DOMAIN_LIST_FILE" ]; then
  help_print
fi  

if [  ! -f $DOMAIN_LIST_FILE ]; then
  echo "ERROR: $DOMAIN_LIST_FILE file not exist"
  help_print
fi  

if [ -z "$OUTPUT_HTML_FILE" ]; then
  OUTPUT_HTML_FILE=list_domain_expire_dates.html
else
  DIR=`dirname   "$OUTPUT_HTML_FILE"`
  if [ ! -d $DIR ]; then
    echo "ERROR: Invalid file path for "$OUTPUT_HTML_FILE""
    help_print
  fi
fi  


for d in `cat $DOMAIN_LIST_FILE`
do
  
  debug_print "----------------"
  debug_print "Domain Name: $d"
  
  check_domain_exists $d
  
  if [ $V_DOMAIN_EXIST -eq 0 ]; then
    generate_html_body $d "Domain not exists" -1
  else
	  
	  expire_date=`whois $d |  egrep -i 'Expiration|Expires on' | head -1  | awk '{print $NF}'|  sed 's/[^0-9a-zA-Z-]*//g'  `
	  expire_date=`date -d $expire_date +"%Y-%m-%d"`
	  debug_print "Expire Date: $expire_date"
	  
	  dt=`date -d $expire_date +"%Y%m%d"`
	  date_remain=`echo $"(( $(date --date="$dt" +%s) - $(date +%s) ))/(60*60*24)"|bc`
	  debug_print "Day Remaining: $date_remain"
	  
	  generate_html_body $d $expire_date $date_remain
  
  fi  
done

outstr=`cat <<- _EOF_
    <HTML>\n
    <HEAD>\n
        <TITLE>\n
        List of Domains with Expiration Dates\n
        </TITLE>\n
    </HEAD>\n
    <BODY>\n
     <H3 align="center">List of Domains with Expiration Dates</H3>\n
     <font color="red">* Red marking for those where remaining days below $CRITICAL_REMAINING_DAY </font><br><br>
     <table border="1" width="100%">\n
       <tr bgcolor="#F0F0F0"><th>Domain</th><th>Expiration Date</th> <th>Remaining days</th>\n
       $html_body \n
      </table> \n
    </BODY>\n
    </HTML> \n
_EOF_`
  

echo -e $outstr > $OUTPUT_HTML_FILE

echo "Output report generated at "$OUTPUT_HTML_FILE