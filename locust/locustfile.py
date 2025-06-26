import random
import string
from locust import FastHttpUser, task, between


def random_url():
    # Generate a random valid URL
    domain = "".join(random.choices(string.ascii_lowercase, k=8))
    tld = random.choice(["com", "net", "org", "io", "dev"])
    return f"https://{domain}.{tld}/path/{random.randint(1, 10000)}"


class UrlShortenerUser(FastHttpUser):
    # wait_time = between(1, 2)

    @task
    def shorten_url(self):
        url = random_url()
        self.client.post("/api/shorten", json={"url": url})
