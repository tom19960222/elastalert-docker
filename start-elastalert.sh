#!/bin/sh

set -e

# Set the timezone.
if [ "$SET_CONTAINER_TIMEZONE" = "true" ]; then
	setup-timezone -z ${CONTAINER_TIMEZONE} && \
	echo "Container timezone set to: $CONTAINER_TIMEZONE"
else
	echo "Container timezone not modified"
fi

# Force immediate synchronisation of the time and start the time-synchronization service.
# In order to be able to use ntpd in the container, it must be run with the SYS_TIME capability.
# In addition you may want to add the SYS_NICE capability, in order for ntpd to be able to modify its priority.
ntpd -s

# Generate elastalert configuration.
envtpl --keep-template -o ${ELASTALERT_CONFIG} ${ELASTALERT_CONFIG_TEMPLATE}

# Wait until Elasticsearch is online since otherwise Elastalert will fail.
rm -f garbage_file
if [ $ELASTICSEARCH_USER -a $ELASTICSEARCH_PASS ]; then
    while ! curl --user $ELASTICSEARCH_USER:$ELASTICSEARCH_PASS -o garbage_file ${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT} 2>/dev/null
    do
        echo "Waiting for Elasticsearch..."
	rm -f garbage_file
	sleep 1
    done

    # Check if the Elastalert index exists in Elasticsearch and create it if it does not.
    if ! curl --user $ELASTICSEARCH_USER:$ELASTICSEARCH_PASS -o garbage_file ${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}/elastalert_status 2>/dev/null
    then
        echo "Creating Elastalert index in Elasticsearch..."
        /usr/bin/elastalert-create-index --host ${ELASTICSEARCH_HOST} --port ${ELASTICSEARCH_PORT} --config ${ELASTALERT_CONFIG} --index elastalert_status --old-index ""
    else
        echo "Elastalert index already exists in Elasticsearch."
    fi
rm -f garbage_file

else
    while ! curl -o garbage_file ${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT} 2>/dev/null
    do
        echo "Waiting for Elasticsearch..."
        rm -f garbage_file
        sleep 1
    done

    # Check if the Elastalert index exists in Elasticsearch and create it if it does not.
    if ! curl -o garbage_file ${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}/elastalert_status 2>/dev/null
    then
        echo "Creating Elastalert index in Elasticsearch..."
        /usr/bin/elastalert-create-index --host ${ELASTICSEARCH_HOST} --port ${ELASTICSEARCH_PORT} --config ${ELASTALERT_CONFIG} --index elastalert_status --old-index ""
    else
        echo "Elastalert index already exists in Elasticsearch."
    fi

fi
rm -f garbage_file
sleep 5

# Check if the Elastalert index exists in Elasticsearch and create it if it does not.

echo "Starting Elastalert..."
exec supervisord -c ${ELASTALERT_SUPERVISOR_CONF} -n
