#!/bin/bash
#
# Copyright 2019 Shiyghan Navti. Email: shiyghan@techequity.company
#
#################################################################################
#### Scanning Content Using Cloud Video Intelligence and Cloud Vision APIs  #####
#################################################################################

function ask_yes_or_no() {
    read -p "$1 ([y]yes to preview, [n]o to create, [d]del to delete): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        n|no)  echo "no" ;;
        d|del) echo "del" ;;
        *)     echo "yes" ;;
    esac
}

function ask_yes_or_no_proj() {
  read -p "$1 ([n]o to skip, or any key to modify): "
  case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
    n|no)  echo "no" ;;
    *)     echo "yes" ;;
  esac
}

export STEP=""
sudo apt-get -qq install pv > /dev/null 2>&1

clear
MODE=1
export TRAINING_ORG_ID=$(gcloud organizations list --format 'value(ID)' --filter="displayName:techequity.training" 2>/dev/null)
export ORG_ID=$(gcloud projects get-ancestors $GCP_PROJECT --format 'value(ID)' 2>/dev/null | tail -1 )
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)  

echo
echo
echo -e "                        👋  Welcome to Cloud Sandbox! 💻"
echo 
echo -e "              *** PLEASE WAIT WHILE LAB UTILITIES ARE INSTALLED ***"
sudo apt-get -qq install pv > /dev/null 2>&1
echo 
export SCRIPTPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

mkdir -p `pwd`/gcp-api-vision-video
export PROJDIR=`pwd`/gcp-api-vision-video
export SCRIPTNAME=gcp-api-vision-video.sh
 
if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=us-central1
EOF
source $PROJDIR/.env
fi

# Display menu options
while :
do
clear
cat<<EOF
=====================================================================
Menu for Scanning Content Using Video Intelligence and Vision APIs
---------------------------------------------------------------------
Please enter number to select your choice:
(1) Enable APIs
(2) Create Cloud Storage buckets
(3) Create Cloud Pub/Sub topics
(4) Create Cloud Storage notifications
(5) Create BigQuery dataset and customize code
(6) Deploy Cloud functions
(7) Test the flow
(G) Launch user guide
(Q) Quit
---------------------------------------------------------------------
EOF
echo "Steps performed${STEP}"
echo
echo "What additional step do you want to perform, e.g. enter 0 to select the execution mode?"
read
clear
case "${REPLY^^}" in

"0")
start=`date +%s`
source $PROJDIR/.env
echo
echo "Do you want to run script in preview mode?"
export ANSWER=$(ask_yes_or_no "Are you sure?")
cd $HOME
if [[ ! -z "$TRAINING_ORG_ID" ]]  &&  [[ $ORG_ID == "$TRAINING_ORG_ID" ]]; then
    export STEP="${STEP},0"
    MODE=1
    if [[ "yes" == $ANSWER ]]; then
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    else 
        if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
            echo 
            echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
            echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
        else
            while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                echo 
                echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                gcloud auth login  --brief --quiet
                export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                if [[ $ACCOUNT != "" ]]; then
                    echo
                    echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                    read GCP_PROJECT
                    gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                    sleep 5
                    export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                fi
            done
            gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
            sleep 2
            gcloud --project $GCP_PROJECT iam service-accounts create $GCP_PROJECT 2>/dev/null
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
            gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
            gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
        fi
        export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
        export IV_BUCKET_NAME=${GCP_PROJECT}-upload
        export FILTERED_BUCKET_NAME=${GCP_PROJECT}-filtered
        export FLAGGED_BUCKET_NAME=${GCP_PROJECT}-flagged
        export STAGING_BUCKET_NAME=${GCP_PROJECT}-staging
        export UPLOAD_NOTIFICATION_TOPIC=upload_notification
        export DATASET_ID=intelligentcontentfilter
        export TABLE_NAME=filtered_content
        cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
EOF
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
        echo
        echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
        echo "*** $PROJDIR/.env ***" | pv -qL 100
        if [[ "yes" == $(ask_yes_or_no_proj "Are you sure?") ]]; then
            echo
            echo "*** NOTE: Setup will proceed using configuration in $PROJDIR/.env" | pv -qL 100
        fi
        if [[ "no" == $ANSWER ]]; then
            MODE=2
            echo
            echo "*** Create mode is active ***" | pv -qL 100
        elif [[ "del" == $ANSWER ]]; then
            export STEP="${STEP},0"
            MODE=3
            echo
            echo "*** Resource delete mode is active ***" | pv -qL 100
        fi
    fi
else 
    if [[ "no" == $ANSWER ]] || [[ "del" == $ANSWER ]] ; then
        export STEP="${STEP},0"
        if [[ -f $SCRIPTPATH/.${SCRIPTNAME}.secret ]]; then
            echo
            unset password
            unset pass_var
            echo -n "Enter access code: " | pv -qL 100
            while IFS= read -p "$pass_var" -r -s -n 1 letter
            do
                if [[ $letter == $'\0' ]]
                then
                    break
                fi
                password=$password"$letter"
                pass_var="*"
            done
            while [[ -z "${password// }" ]]; do
                unset password
                unset pass_var
                echo
                echo -n "You must enter an access code to proceed: " | pv -qL 100
                while IFS= read -p "$pass_var" -r -s -n 1 letter
                do
                    if [[ $letter == $'\0' ]]
                    then
                        break
                    fi
                    password=$password"$letter"
                    pass_var="*"
                done
            done
            export PASSCODE=$(cat $SCRIPTPATH/.${SCRIPTNAME}.secret | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$password 2> /dev/null)
            if [[ $PASSCODE == 'AccessVerified' ]]; then
                MODE=2
                echo && echo
                echo "*** Access code is valid ***" | pv -qL 100
                if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
                    echo 
                    echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
                    echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
                else
                    while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                        echo 
                        echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                        gcloud auth login  --brief --quiet
                        export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                        if [[ $ACCOUNT != "" ]]; then
                            echo
                            echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                            read GCP_PROJECT
                            gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                            sleep 3
                            export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                        fi
                    done
                    gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
                    sleep 2
                    gcloud --project $GCP_PROJECT iam service-accounts create $GCP_PROJECT 2>/dev/null
                    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
                    gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
                    gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
                fi
                export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
                export IV_BUCKET_NAME=${GCP_PROJECT}-upload
                export FILTERED_BUCKET_NAME=${GCP_PROJECT}-filtered
                export FLAGGED_BUCKET_NAME=${GCP_PROJECT}-flagged
                export STAGING_BUCKET_NAME=${GCP_PROJECT}-staging
                export UPLOAD_NOTIFICATION_TOPIC=upload_notification
                export DATASET_ID=intelligentcontentfilter
                export TABLE_NAME=filtered_content
                cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
EOF
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
                echo
                echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
                echo "*** $PROJDIR/.env ***" | pv -qL 100
                if [[ "no" == $ANSWER ]]; then
                    MODE=2
                    echo
                    echo "*** Create mode is active ***" | pv -qL 100
                elif [[ "del" == $ANSWER ]]; then
                    export STEP="${STEP},0"
                    MODE=3
                    echo
                    echo "*** Resource delete mode is active ***" | pv -qL 100
                fi
            else
                echo && echo
                echo "*** Access code is invalid ***" | pv -qL 100
                echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
                echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
                echo
                echo "*** Command preview mode is active ***" | pv -qL 100
            fi
        else
            echo
            echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
            echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
            echo
            echo "*** Command preview mode is active ***" | pv -qL 100
        fi
    else
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    fi
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"1")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},1i"
    echo
    echo "$ gcloud services enable --project=\$GCP_PROJECT storage.googleapis.com bigquery.googleapis.com pubsub.googleapis.com cloudfunctions.googleapis.com # to enable APIs" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "$ gcloud services enable --project=$GCP_PROJECT storage.googleapis.com bigquery.googleapis.com pubsub.googleapis.com cloudfunctions.googleapis.com # to enable APIs" | pv -qL 100
    gcloud services enable --project=$GCP_PROJECT storage.googleapis.com bigquery.googleapis.com pubsub.googleapis.com cloudfunctions.googleapis.com 
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},1i"
    echo
    echo "1. Enable APIs" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"2")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},2i"
    echo
    echo "$ gsutil mb gs://\$IV_BUCKET_NAME # to create a bucket for storing  uploaded images and video files" | pv -qL 100
    echo
    echo "$ gsutil mb gs://\$FILTERED_BUCKET_NAME # to create bucket for storing filtered image and video files" | pv -qL 100
    echo
    echo "$ gsutil mb gs://\$FLAGGED_BUCKET_NAME # to create bucket for storing flagged image and video files" | pv -qL 100
    echo
    echo "$ gsutil mb gs://\$STAGING_BUCKET_NAME # to create bucket for Cloud Functions to use as a staging location" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},2"
    echo
    echo "$ gsutil mb gs://$IV_BUCKET_NAME # to create a bucket for storing  uploaded images and video files" | pv -qL 100
    gsutil mb gs://$IV_BUCKET_NAME
    echo
    echo "$ gsutil mb gs://$FILTERED_BUCKET_NAME # to create bucket for storing filtered image and video files" | pv -qL 100
    gsutil mb gs://$FILTERED_BUCKET_NAME
    echo
    echo "$ gsutil mb gs://$FLAGGED_BUCKET_NAME # to create bucket for storing flagged image and video files" | pv -qL 100
    gsutil mb gs://$FLAGGED_BUCKET_NAME 
    echo
    echo "$ gsutil mb gs://$STAGING_BUCKET_NAME # to create bucket for Cloud Functions to use as a staging location" | pv -qL 100
    gsutil mb gs://$STAGING_BUCKET_NAME
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},2x"
    echo
    echo "*** Not implemented ***" | pv -qL 100
else
    export STEP="${STEP},2i"
    echo
    echo "*** Not implemented ***" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"3")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},3i"
    echo
    echo "$ gcloud pubsub topics create \$UPLOAD_NOTIFICATION_TOPIC # to create topic to receive Cloud Storage notifications when files are uploaded to Cloud Storage" | pv -qL 100
    echo
    echo "$ gcloud pubsub topics create visionapiservice # to create topic to receive messages from the Vision API" | pv -qL 100
    echo
    echo "$ gcloud pubsub topics create videointelligenceservice # to create a topic to receive messages from Video Intelligence API" | pv -qL 100
    echo
    echo "$ gcloud pubsub topics create bqinsert # to create topic to receive  messages to store in BigQuery" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3"
    echo
    echo "$ gcloud pubsub topics create $UPLOAD_NOTIFICATION_TOPIC # to create topic to receive Cloud Storage notifications when files are uploaded to Cloud Storage" | pv -qL 100
    gcloud pubsub topics create $UPLOAD_NOTIFICATION_TOPIC
    echo
    echo "$ gcloud pubsub topics create visionapiservice # to create topic to receive messages from the Vision API" | pv -qL 100
    gcloud pubsub topics create visionapiservice
    echo
    echo "$ gcloud pubsub topics create videointelligenceservice # to create a topic to receive messages from Video Intelligence API" | pv -qL 100
    gcloud pubsub topics create videointelligenceservice
    echo
    echo "$ gcloud pubsub topics create bqinsert # to create topic to receive  messages to store in BigQuery" | pv -qL 100
    gcloud pubsub topics create bqinsert
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x"
    echo
    echo "*** Not implemented ***" | pv -qL 100
else
    export STEP="${STEP},3i"
    echo
    echo "*** Not implemented ***" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"4")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},4i"
    echo
    echo "$ gsutil notification create -t upload_notification -f json -e OBJECT_FINALIZE gs://\$IV_BUCKET_NAME # to create notification that is triggered only when one of new objects is placed in the Cloud Storage file upload bucket" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},4"
    echo
    echo "$ gsutil notification create -t upload_notification -f json -e OBJECT_FINALIZE gs://$IV_BUCKET_NAME # to create notification that is triggered only when one of new objects is placed in the Cloud Storage file upload bucket" | pv -qL 100
    gsutil notification create -t upload_notification -f json -e OBJECT_FINALIZE gs://$IV_BUCKET_NAME
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},4x"
    echo
    echo "*** Not implemented ***" | pv -qL 100
else
    export STEP="${STEP},4i"
    echo
    echo "*** Not implemented ***" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"5")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},5i"
    echo
    echo "$ bq --project_id \$GCP_PROJECT mk \$DATASET_ID # to create BigQuery dataset" | pv -qL 100
    echo
    echo "$ bq --project_id \$GCP_PROJECT mk --schema \$PROJDIR/cloud-functions-intelligentcontent-nodejs/intelligent_content_bq_schema.json -t \${DATASET_ID}.\${TABLE_NAME} # to create BigQuery table from schema file" | pv -qL 100
    echo
    echo "$ bq --project_id \$GCP_PROJECT show \${DATASET_ID}.\${TABLE_NAME} # to verify BigQuery table has been created" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},5"
    echo
    rm -rf $PROJDIR/cloud-functions-intelligentcontent-nodejs && mkdir -p $PROJDIR/cloud-functions-intelligentcontent-nodejs
    echo "$ gsutil -m cp -r gs://spls/gsp138/cloud-functions-intelligentcontent-nodejs $PROJDIR # to download code from bucket" | pv -qL 100
    gsutil -m cp -r gs://spls/gsp138/cloud-functions-intelligentcontent-nodejs $PROJDIR
    echo
    echo "$ bq --project_id $GCP_PROJECT mk $DATASET_ID # to create BigQuery dataset" | pv -qL 100
    bq --project_id $GCP_PROJECT mk $DATASET_ID
    echo
    echo "$ bq --project_id $GCP_PROJECT mk --schema $PROJDIR/cloud-functions-intelligentcontent-nodejs/intelligent_content_bq_schema.json -t ${DATASET_ID}.${TABLE_NAME} # to create BigQuery table from schema file" | pv -qL 100
    bq --project_id $GCP_PROJECT mk --schema $PROJDIR/cloud-functions-intelligentcontent-nodejs/intelligent_content_bq_schema.json -t ${DATASET_ID}.${TABLE_NAME}
    echo
    echo "$ bq --project_id $GCP_PROJECT show ${DATASET_ID}.${TABLE_NAME} # to verify BigQuery table has been created" | pv -qL 100
    bq --project_id $GCP_PROJECT show ${DATASET_ID}.${TABLE_NAME}
    echo
    echo "$ sed -i \"s/\[PROJECT-ID\]/$GCP_PROJECT/g\" $PROJDIR/cloud-functions-intelligentcontent-nodejs/config.json # to localise json file" | pv -qL 100
    sed -i "s/\[PROJECT-ID\]/$GCP_PROJECT/g" $PROJDIR/cloud-functions-intelligentcontent-nodejs/config.json
    echo
    echo "$ sed -i \"s/\[FLAGGED_BUCKET_NAME\]/$FLAGGED_BUCKET_NAME/g\" $PROJDIR/cloud-functions-intelligentcontent-nodejs/config.json # to localise json file" | pv -qL 100
    sed -i "s/\[FLAGGED_BUCKET_NAME\]/$FLAGGED_BUCKET_NAME/g" $PROJDIR/cloud-functions-intelligentcontent-nodejs/config.json
    echo
    echo "$ sed -i \"s/\[FILTERED_BUCKET_NAME\]/$FILTERED_BUCKET_NAME/g\" $PROJDIR/cloud-functions-intelligentcontent-nodejs/config.json # to localise json file" | pv -qL 100
    sed -i "s/\[FILTERED_BUCKET_NAME\]/$FILTERED_BUCKET_NAME/g" $PROJDIR/cloud-functions-intelligentcontent-nodejs/config.json
    echo
    echo "$ sed -i \"s/\[DATASET_ID\]/$DATASET_ID/g\" $PROJDIR/cloud-functions-intelligentcontent-nodejs/config.json # to localise json file" | pv -qL 100
    sed -i "s/\[DATASET_ID\]/$DATASET_ID/g" $PROJDIR/cloud-functions-intelligentcontent-nodejs/config.json
    echo
    echo "$ sed -i \"s/\[TABLE_NAME\]/$TABLE_NAME/g\" $PROJDIR/cloud-functions-intelligentcontent-nodejs/config.json # to localise json file" | pv -qL 100
    sed -i "s/\[TABLE_NAME\]/$TABLE_NAME/g" $PROJDIR/cloud-functions-intelligentcontent-nodejs/config.json
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},5x"
    echo
    echo "*** Not implemented ***" | pv -qL 100
else
    export STEP="${STEP},5i"
    echo
    echo "*** Not implemented ***" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"6")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},6i"
    echo
    echo "$ gcloud functions deploy GCStoPubsub --runtime nodejs12 --stage-bucket gs://\$STAGING_BUCKET_NAME --trigger-topic \$UPLOAD_NOTIFICATION_TOPIC --entry-point GCStoPubsub --quiet # to deploy function to receive a Cloud Storage notification message from Cloud Pub/Sub and forward the message to another function with another Cloud Pub/Sub message" | pv -qL 100
    echo
    echo "$ gcloud functions deploy visionAPI --runtime nodejs12 --stage-bucket gs://\$STAGING_BUCKET_NAME --trigger-topic visionapiservice --entry-point visionAPI --quiet # to deploy function with logic to receive message with Cloud Pub/Sub, call Vision API, and forward message to the insertIntoBigQuery Cloud Function with another Cloud Pub/Sub message" | pv -qL 100
    echo
    echo "$ gcloud functions deploy videoIntelligenceAPI --runtime nodejs12 --stage-bucket gs://\$STAGING_BUCKET_NAME --trigger-topic videointelligenceservice --entry-point videoIntelligenceAPI --timeout 540 --quiet # to deploy function which contains the logic to receive a message with Cloud Pub/Sub, call the Video Intelligence API, and forward the message to the insertIntoBigQuery Cloud Function with another Cloud Pub/Sub message" | pv -qL 100
    echo
    echo "$ gcloud functions deploy insertIntoBigQuery --runtime nodejs12 --stage-bucket gs://\$STAGING_BUCKET_NAME --trigger-topic bqinsert --entry-point insertIntoBigQuery --quiet # to deploy function which contains the logic to receive a message with Cloud Pub/Sub and call the BigQuery API to insert the data into BigQuery table" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},6"
    cd $PROJDIR/cloud-functions-intelligentcontent-nodejs
    echo
    echo "$ gcloud functions deploy GCStoPubsub --runtime nodejs12 --stage-bucket gs://$STAGING_BUCKET_NAME --trigger-topic $UPLOAD_NOTIFICATION_TOPIC --entry-point GCStoPubsub --quiet # to deploy function to receive a Cloud Storage notification message from Cloud Pub/Sub and forward the message to another function with another Cloud Pub/Sub message" | pv -qL 100
    gcloud functions deploy GCStoPubsub --runtime nodejs12 --stage-bucket gs://$STAGING_BUCKET_NAME --trigger-topic $UPLOAD_NOTIFICATION_TOPIC --entry-point GCStoPubsub --quiet
    echo
    echo "$ gcloud functions deploy visionAPI --runtime nodejs12 --stage-bucket gs://$STAGING_BUCKET_NAME --trigger-topic visionapiservice --entry-point visionAPI --quiet # to deploy function with logic to receive message with Cloud Pub/Sub, call Vision API, and forward message to the insertIntoBigQuery Cloud Function with another Cloud Pub/Sub message" | pv -qL 100
    gcloud functions deploy visionAPI --runtime nodejs12 --stage-bucket gs://$STAGING_BUCKET_NAME --trigger-topic visionapiservice --entry-point visionAPI --quiet
    echo
    echo "$ gcloud functions deploy videoIntelligenceAPI --runtime nodejs12 --stage-bucket gs://$STAGING_BUCKET_NAME --trigger-topic videointelligenceservice --entry-point videoIntelligenceAPI --timeout 540 --quiet # to deploy function which contains the logic to receive a message with Cloud Pub/Sub, call the Video Intelligence API, and forward the message to the insertIntoBigQuery Cloud Function with another Cloud Pub/Sub message" | pv -qL 100
    gcloud functions deploy videoIntelligenceAPI --runtime nodejs12 --stage-bucket gs://$STAGING_BUCKET_NAME --trigger-topic videointelligenceservice --entry-point videoIntelligenceAPI --timeout 540 --quiet
    echo
    echo "$ gcloud functions deploy insertIntoBigQuery --runtime nodejs12 --stage-bucket gs://$STAGING_BUCKET_NAME --trigger-topic bqinsert --entry-point insertIntoBigQuery --quiet # to deploy function which contains the logic to receive a message with Cloud Pub/Sub and call the BigQuery API to insert the data into BigQuery table" | pv -qL 100
    gcloud functions deploy insertIntoBigQuery --runtime nodejs12 --stage-bucket gs://$STAGING_BUCKET_NAME --trigger-topic bqinsert --entry-point insertIntoBigQuery --quiet
    cd $HOME
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},6x"
    echo
    echo "*** Not implemented ***" | pv -qL 100
else
    export STEP="${STEP},6i"
    echo
    echo "*** Not implemented ***" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"7")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},7i"
    echo
    echo "$ gcloud beta functions logs read --filter \"finished with status\" \"GCStoPubsub\" --limit 100 # to test GCStoPubsub" | pv -qL 100
    echo
    echo "$ gcloud beta functions logs read --filter \"finished with status\" \"insertIntoBigQuery\" --limit 100 # to test insertIntoBigQuery" | pv -qL 100
    echo
    echo "$ echo \"
#standardSql
SELECT insertTimestamp,
  contentUrl,
  flattenedSafeSearch.flaggedType,
  flattenedSafeSearch.likelihood
FROM \`\$GCP_PROJECT.\$DATASET_ID.\$TABLE_NAME\`
CROSS JOIN UNNEST(safeSearch) AS flattenedSafeSearch
ORDER BY insertTimestamp DESC,
  contentUrl,
  flattenedSafeSearch.flaggedType
LIMIT 1000
\" > $PROJDIR/sql.txt # to customise query" | pv -qL 100
    echo
    echo "$ bq --project_id \$GCP_PROJECT query < $PROJDIR/sql.txt # to view BigQuery results" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},7"
    echo
    echo "$ curl https://file-examples.com/wp-content/uploads/2018/04/file_example_MOV_480_700kB.mov -o $PROJDIR/file_example_MOV_480_700kB.mov # to download large file" | pv -qL 100
    curl https://file-examples.com/wp-content/uploads/2018/04/file_example_MOV_480_700kB.mov -o $PROJDIR/file_example_MOV_480_700kB.mov
    echo
    echo "$ gsutil cp $PROJDIR/file_example_MOV_480_700kB.mov gs://$IV_BUCKET_NAME # to copy files" | pv -qL 100
    gsutil cp $PROJDIR/file_example_MOV_480_700kB.mov gs://$IV_BUCKET_NAME
    echo
    echo $ sleep 30 # to wait"
    sleep 30
    echo
    echo "$ gcloud beta functions logs read --filter \"finished with status\" \"GCStoPubsub\" --limit 100 # to test GCStoPubsub" | pv -qL 100
    gcloud beta functions logs read --filter "finished with status" "GCStoPubsub" --limit 100
    echo
    echo $ sleep 60 # to wait"
    echo && echo
    echo "$ gcloud beta functions logs read --filter \"finished with status\" \"insertIntoBigQuery\" --limit 100 # to test insertIntoBigQuery" | pv -qL 100
    gcloud beta functions logs read --filter "finished with status" "insertIntoBigQuery" --limit 100 
    echo
    echo "$ echo \"
#standardSql
SELECT insertTimestamp,
  contentUrl,
  flattenedSafeSearch.flaggedType,
  flattenedSafeSearch.likelihood
FROM \`$GCP_PROJECT.$DATASET_ID.$TABLE_NAME\`
CROSS JOIN UNNEST(safeSearch) AS flattenedSafeSearch
ORDER BY insertTimestamp DESC,
  contentUrl,
  flattenedSafeSearch.flaggedType
LIMIT 1000
\" > sql.txt # to customise query" | pv -qL 100
    echo "
#standardSql
SELECT insertTimestamp,
  contentUrl,
  flattenedSafeSearch.flaggedType,
  flattenedSafeSearch.likelihood
FROM \`$GCP_PROJECT.$DATASET_ID.$TABLE_NAME\`
CROSS JOIN UNNEST(safeSearch) AS flattenedSafeSearch
ORDER BY insertTimestamp DESC,
  contentUrl,
  flattenedSafeSearch.flaggedType
LIMIT 1000
" > $PROJDIR/sql.txt
    echo
    echo "$ bq --project_id $GCP_PROJECT query < $PROJDIR/sql.txt # to view BigQuery results" | pv -qL 100
    bq --project_id $GCP_PROJECT query < $PROJDIR/sql.txt
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},7x"
    echo
    echo "*** Not implemented ***" | pv -qL 100
else
    export STEP="${STEP},7i"
    echo
    echo "*** Not implemented ***" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"R")
echo
echo "
  __                      __                              __                               
 /|            /         /              / /              /                 | /             
( |  ___  ___ (___      (___  ___        (___           (___  ___  ___  ___|(___  ___      
  | |___)|    |   )     |    |   )|   )| |    \   )         )|   )|   )|   )|   )|   )(_/_ 
  | |__  |__  |  /      |__  |__/||__/ | |__   \_/       __/ |__/||  / |__/ |__/ |__/  / / 
                                 |              /                                          
"
echo "
We are a group of information technology professionals committed to driving cloud 
adoption. We create cloud skills development assets during our client consulting 
engagements, and use these assets to build cloud skills independently or in partnership 
with training organizations.
 
You can access more resources from our iOS and Android mobile applications.

iOS App: https://apps.apple.com/us/app/tech-equity/id1627029775
Android App: https://play.google.com/store/apps/details?id=com.techequity.app

Email:support@techequity.cloud 
Web: https://techequity.cloud

Ⓒ Tech Equity 2022" | pv -qL 100
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"G")
cloudshell launch-tutorial $SCRIPTPATH/.tutorial.md
;;

"Q")
echo
exit
;;
"q")
echo
exit
;;
* )
echo
echo "Option not available"
;;
esac
sleep 1
done