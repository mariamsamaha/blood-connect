import os
import random
from locust import HttpUser, task, between

class BloodConnectUser(HttpUser):
    # Simulated think time between user actions (1 to 3 seconds)
    wait_time = between(1, 3)

    def on_start(self):
        """
        Called when a simulated user starts.
        Sets up the authentication headers.
        """
        # Load token from environment or use a default mock token for local testing
        self.auth_token = os.environ.get("FIREBASE_TEST_TOKEN", "mock_firebase_token")
        self.headers = {
            "Authorization": f"Bearer {self.auth_token}",
            "Content-Type": "application/json"
        }

    @task(5)
    def view_active_requests(self):
        """Simulates users checking active blood donation requests."""
        self.client.get("/api/v1/requests/active", headers=self.headers)

    @task(3)
    def view_leaderboard(self):
        """Simulates users checking the donor leaderboard."""
        self.client.get("/api/v1/donor/leaderboard", headers=self.headers)

    @task(3)
    def view_profile_and_badges(self):
        """Simulates a user viewing their own profile and badges progress."""
        self.client.get("/api/v1/users/me", headers=self.headers)
        self.client.get("/api/v1/users/me/badges", headers=self.headers)
        self.client.get("/api/v1/users/me/badges/progress", headers=self.headers)

    @task(2)
    def check_ai_eligibility(self):
        """Simulates checking AI eligibility for a donation."""
        blood_types = ["A+", "O+", "B+", "AB+", "A-", "O-", "B-", "AB-"]
        payload = {
            "donorId": "test_donor_123",
            "bloodType": random.choice(blood_types),
            "feelingWell": True,
            "recentIllness": False
        }
        self.client.post("/api/v1/ai/eligibility", json=payload, headers=self.headers)

    @task(2)
    def check_donor_matches(self):
        """Simulates looking up matched requests for a donor."""
        self.client.get("/api/v1/donor/matches", headers=self.headers)

    @task(1)
    def health_check(self):
        """Simulates hitting health check endpoints."""
        self.client.get("/")
        self.client.get("/health/db")
