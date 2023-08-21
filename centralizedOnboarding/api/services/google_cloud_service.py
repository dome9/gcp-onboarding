from google.cloud import pubsub_v1
from google.cloud import logging
from google.oauth2 import service_account
import googleapiclient.discovery
from google.cloud.pubsub_v1.types import PushConfig


class GoogleCloudService:
    def __init__(self, credentials_path):
        self.credentials = service_account.Credentials.from_service_account_file(filename=credentials_path)

    def create_service_account(self, project_id, service_account_name):
        try:
            service = googleapiclient.discovery.build("iam", "v1", credentials=self.credentials)
            existing_service_accounts = (
                service.projects().serviceAccounts().list(name="projects/" + project_id).execute())
            cloud_guard_service_account = list(
                filter(lambda obj: service_account_name in obj["email"], existing_service_accounts['accounts']))
            if not cloud_guard_service_account:
                my_service_account = (service.projects().serviceAccounts().create(
                    name="projects/" + project_id,
                    body={"accountId": service_account_name, "serviceAccount": {"displayName": service_account_name}},
                ).execute())
                print(f"Created service account: {my_service_account['email']}.")
                return my_service_account['email']
            else:
                print(f"Service account {cloud_guard_service_account[0]['email']} already exists.")
                return cloud_guard_service_account[0]['email']
        except Exception as e:
            raise Exception(f"Failed to create service account, {e}")

    def delete_service_accounts(self, project_id, service_accounts):
        for service_account in service_accounts:
            try:
                service = googleapiclient.discovery.build("iam", "v1", credentials=self.credentials)
                existing_service_accounts = (
                    service.projects().serviceAccounts().list(name="projects/" + project_id).execute())
                cloud_guard_service_account = list(
                    filter(lambda obj: service_account in obj["email"], existing_service_accounts['accounts']))
                if cloud_guard_service_account:
                    (service.projects().serviceAccounts().delete(
                        name=cloud_guard_service_account[0]["name"]
                    ).execute())
                    print(f"Service account: {cloud_guard_service_account[0]['email']} deleted.")
            except Exception as e:
                print(f"Failed to delete service account {service_account}, {e}")

    def create_pubsub_topic(self, project_id, topic_id):
        try:
            pubsub_publisher_client = pubsub_v1.PublisherClient(credentials=self.credentials)
            topic_path = pubsub_publisher_client.topic_path(project_id, topic_id)
            pubsub_publisher_client.get_topic(request={"topic": topic_path})
            print(f"Pub/Sub topic {topic_path} already exists.")
            return topic_path
        except Exception as e:
            if e.code == 404:
                pubsub_publisher_client.create_topic(request={"name": topic_path})
                print(f"Created Pub/Sub topic: '{topic_path}'.")
                return topic_path
            else:
                raise Exception(f"Failed to create Pub/Sub topic, {e}")

    def delete_pubsub_topics(self, topics):
        for topic in topics:
            try:
                pubsub_publisher_client = pubsub_v1.PublisherClient(credentials=self.credentials)
                pubsub_publisher_client.delete_topic(request={"topic": topic})
                print(f"Pub/Sub topic {topic} deleted.")
            except Exception as e:
                # not exists
                if e.code == 404:
                    pass
                else:
                    print(f"Failed to delete Pub/Sub topic {topic}, {e}")

    def create_pubsub_subscription(self, project_id, subscription_name, topic_name, service_account_name,
                                   validator_endpoint):
        try:
            pubsub_subscriber_client = pubsub_v1.SubscriberClient(credentials=self.credentials)
            subscription_path = pubsub_subscriber_client.subscription_path(project_id, subscription_name)
            pubsub_subscriber_client.get_subscription(request={"subscription": subscription_path})
            print(f"Pub/Sub subscription {subscription_path} already exists.")
            return subscription_path
        except Exception as e:
            if e.code == 404:
                # Create the subscription
                push_config = PushConfig(
                    push_endpoint=validator_endpoint,
                    oidc_token=PushConfig.OidcToken(
                        service_account_email=service_account_name,
                        audience="dome9-gcp-logs-collector"
                    ))
                pubsub_subscriber_client.create_subscription(
                    request={
                        "name": subscription_path,
                        "topic": topic_name,
                        "ack_deadline_seconds": 60,
                        "expiration_policy": {},
                        "retry_policy": {
                            "minimum_backoff": "10s",
                            "maximum_backoff": "60s"
                        },
                        "push_config": push_config
                    }
                )
                print(f"Created Pub/Sub subscription: {subscription_path}.")
                return subscription_path
            else:
                raise Exception(f"Failed to create Pub/Sub subscription, {e}")

    def delete_pubsub_subscriptions(self, subscriptions):
        for subscription in subscriptions:
            try:
                pubsub_subscriber_client = pubsub_v1.SubscriberClient(credentials=self.credentials)
                with pubsub_subscriber_client:
                    pubsub_subscriber_client.delete_subscription(request={"subscription": subscription})
                print(f"Pub/Sub subscription {subscription} deleted.")
            except Exception as e:
                # not exists
                if e.code == 404:
                    pass
                else:
                    print(f"Failed to delete Pub/Sub subscription {subscription}, {e}")

    def create_logging_sink(self, sink_project_id, sink_name, topic_name, log_filter):
        try:
            pubsub_publisher_client = pubsub_v1.PublisherClient(credentials=self.credentials)
            logging_client = logging.Client(project=sink_project_id, credentials=self.credentials)
            sink = logging_client.sink(sink_name, filter_=log_filter, destination=f"pubsub.googleapis.com/{topic_name}")
            if sink.exists():
                print(f"Sink {sink.name} already exists.")
            else:
                sink.create(unique_writer_identity=True)
                print(f"Created sink {sink.name}")
                policy = pubsub_publisher_client.get_iam_policy(request={"resource": topic_name})
                policy.bindings.add(role="roles/pubsub.publisher", members=[sink.writer_identity])
                pubsub_publisher_client.set_iam_policy(
                    request={"resource": topic_name, "policy": policy}
                )
            return {"ProjectId": sink_project_id, "SinkName": sink_name, "TopicName": topic_name}
        except Exception as e:
            raise Exception(f"Failed to create {sink_name} in {sink_project_id} project, {e}")

    def delete_logging_sinks(self, sinks):
        for sink in sinks:
            try:
                logging_client = logging.Client(project=sink['projectId'], credentials=self.credentials)
                logging_sink = logging_client.sink(sink['sinkName'])
                if logging_sink.exists():
                    logging_sink.delete()
                    print(f"Sink {logging_sink.name} deleted.")
                # not exists
                else:
                    pass
            except Exception as e:
                print(f"Failed to delete sink: {sink['sinkName']}, {e}")

    def delete_cloudguard_resources(self, project_id, service_account_list, topic_list, subscription_list, sink_list):
        self.delete_service_accounts(project_id, service_account_list)
        self.delete_pubsub_topics(topic_list)
        self.delete_pubsub_subscriptions(subscription_list)
        self.delete_logging_sinks(sink_list)

    def get_credentials(self):
        return self.credentials
