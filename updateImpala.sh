#!/bin/sh
set -x

IMPALAD=$1
ENVIRONMENT=$2
CONFIG_FILE=$3

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
. ${SCRIPT_DIR}/${CONFIG_FILE}

if ${USE_SECURITY}; then
 kinit ${KEYTAB_USER} -k -t ${KEYTAB_FILE}
fi

for filename in $(find -name 'update_*.sql'); do

 echo '==============================' + $filename + '======================================='

 COUNT_SCRIPT="select count(*) from ${ENVIRONMENT}_state.updates where uid='$filename';"
 COUNT_RESULT=$(/bin/impala-shell -i $IMPALAD --var=ENV=$ENVIRONMENT -q "$COUNT_SCRIPT")
 echo $COUNT_RESULT
 COUNT_OF_CUR_UPDATE=`echo $COUNT_RESULT | awk '{print $7}'`
 echo $COUNT_OF_CUR_UPDATE

 if [ "$COUNT_OF_CUR_UPDATE" -eq 0 ]; then
  SCRIPT_AUTHOR=$(awk '/--author/ {for (i=2; i<NF; i++) printf $i " "; print $NF}' $filename)
  SCRIPT_TITLE=$(awk '/--title/ {for (i=2; i<NF; i++) printf $i " "; print $NF}' $filename)
  TRANSACTION_NUM=$(awk '/--transaction/ {printf $2}' $filename)

  UPDATE_STATE_SCRIPT="insert into ${ENVIRONMENT}_state.updates values (1, '$filename', '$SCRIPT_TITLE', NOW(), '$SCRIPT_AUTHOR');"

 echo 'run ' + $filename

 if ${USE_SECURITY}; then
  if [ "`/bin/impala-shell -k -i $IMPALAD --var=ENV=$ENVIRONMENT -f $filename`" ]
  then
   /bin/impala-shell -k -i $IMPALAD --var=ENV=$ENVIRONMENT -q "$UPDATE_STATE_SCRIPT"
   echo -e "\e[92mState was updated"
   tput sgr0
  else
   echo -e "\e[91mScript [ ' + $filename + ' ] is broken"
   tput sgr0

   #start rollback
   if [ $TRANSACTION_NUM = 2 ] || [ $TRANSACTION_NUM = 3 ]; then
    #rallback 1
    ROLLBACK_FILE_NAME_1=$filename | sed "s/${TRANSACTION_NUM}.sql/rollback_1.sql/g"
    /bin/impala-shell -k -i $IMPALAD --var=ENV=$ENVIRONMENT -f $ROLLBACK_FILE_NAME_1
    #rallback 0
    ROLLBACK_FILE_NAME_0=$filename | sed "s/${TRANSACTION_NUM}.sql/rollback_0.sql/g"
    /bin/impala-shell -k -i $IMPALAD --var=ENV=$ENVIRONMENT -f $ROLLBACK_FILE_NAME_0
   ls
   fi

   if [ $TRANSACTION_NUM = 1 ]; then
    #rallback 0
    ROLLBACK_FILE_NAME_0=$filename | sed "s/${TRANSACTION_NUM}.sql/rollback_0.sql/g"
    /bin/impala-shell -k -i $IMPALAD --var=ENV=$ENVIRONMENT -f $ROLLBACK_FILE_NAME_0
   ls
   fi
   #end rollback

  fi
 else
  if [ "`/bin/impala-shell -i $IMPALAD --var=ENV=$ENVIRONMENT -f $filename`" ]
  then
   /bin/impala-shell -i $IMPALAD --var=ENV=$ENVIRONMENT -q "$UPDATE_STATE_SCRIPT"
   echo -e "\e[92mState was updated"
   tput sgr0
  else
   echo -e "\e[91mScript [ ' + $filename + ' ] is broken"
   tput sgr0

      #start rollback
   if [ $TRANSACTION_NUM = 2 ] || [ $TRANSACTION_NUM = 3 ]; then
    #rallback 1
    ROLLBACK_FILE_NAME_1=$filename | sed "s/${TRANSACTION_NUM}.sql/rollback_1.sql/g"
    /bin/impala-shell -i $IMPALAD --var=ENV=$ENVIRONMENT -f $ROLLBACK_FILE_NAME_1
    #rallback 0
    ROLLBACK_FILE_NAME_0=$filename | sed "s/${TRANSACTION_NUM}.sql/rollback_0.sql/g"
    /bin/impala-shell -i $IMPALAD --var=ENV=$ENVIRONMENT -f $ROLLBACK_FILE_NAME_0
   ls
   fi

   if [ $TRANSACTION_NUM = 1 ]; then
    #rallback 0
    ROLLBACK_FILE_NAME_0=$filename | sed "s/${TRANSACTION_NUM}.sql/rollback_0.sql/g"
    /bin/impala-shell -i $IMPALAD --var=ENV=$ENVIRONMENT -f $ROLLBACK_FILE_NAME_0
   ls
   fi
   #end rollback

  fi
 fi

 echo 'done with ' + $filename


else
 echo -e "\e[36mThe update [ " + $filename + " ] was already executed."
 tput sgr0
fi
echo -e "\n"
done

