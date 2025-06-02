import random
from collections import defaultdict
import json
import os
import re

# Check if running on Replit
IS_REPLIT = "REPLIT_DB_URL" in os.environ

if IS_REPLIT:
    from replit import db

class JoerAI:
    def __init__(self):
        self.knowledge_base = defaultdict(list)
        self.response_weights = defaultdict(lambda: 0.0)  # Initialize with 0 as the base weight
        self.context_memory = []
        self.data_file = "joerai_brain.json"
        self.restrictions = self.load_restrictions()
        self.load_knowledge()

    def load_restrictions(self):
        """Load restrictions from the JSON file."""
        if IS_REPLIT:
            if "joerai_brain" in db:
                data = json.loads(db["joerai_brain"])
                return data.get('restrictions', {})
        else:
            if os.path.exists(self.data_file):
                with open(self.data_file, 'r') as f:
                    data = json.load(f)
                    return data.get('restrictions', {})
        return {}

    def is_restricted(self, text):
        """Check if the user input matches any restricted topics."""
        restricted_topics = self.restrictions.get('restricted_topics', [])
        for topic in restricted_topics:
            if topic.lower() in text.lower():
                return True
        return False

    def learn_from_interaction(self, user_input, response, feedback_score):
        """Learn from an interaction only if it's not a restricted topic."""
        if self.is_restricted(user_input):
            print("JoerAI: I am sorry, I either can't talk about that or I can't learn that yet.")
            return  # Ignore learning for restricted topics

        key = self.get_context_key(user_input)
        # Add the response to the knowledge base if it's a new response
        if response not in self.knowledge_base[key]:
            self.knowledge_base[key].append(response)

        # Clamp feedback score to the range of -5 to 10
        feedback_score = max(min(feedback_score, 10), -5)

        # Adjust the weight based on the feedback
        current_weight = self.response_weights[(key, response)]
        new_weight = current_weight + feedback_score

        # Clamp the new weight to the range of -5 to 10
        self.response_weights[(key, response)] = max(min(new_weight, 10), -5)

        # Save the updated knowledge and response weights
        self.save_knowledge()

    def save_knowledge(self):
        save_data = {
            'knowledge_base': dict(self.knowledge_base),
            'response_weights': {str(k): v for k, v in self.response_weights.items()},
            'restrictions': self.restrictions
        }

        if IS_REPLIT:
            # Save to Replit's persistent storage
            db["joerai_brain"] = json.dumps(save_data)
        else:
            # Save locally
            with open(self.data_file, 'w') as f:
                json.dump(save_data, f)

    def load_knowledge(self):
        if IS_REPLIT:
            if "joerai_brain" in db:
                data = json.loads(db["joerai_brain"])
                self.knowledge_base.update(data['knowledge_base'])
                self.response_weights = defaultdict(lambda: 0.0)
                for k, v in data['response_weights'].items():
                    key = tuple(eval(k))
                    self.response_weights[key] = v
                self.restrictions = data.get('restrictions', {})
        else:
            if os.path.exists(self.data_file):
                with open(self.data_file, 'r') as f:
                    data = json.load(f)
                    self.knowledge_base.update(data['knowledge_base'])
                    self.response_weights = defaultdict(lambda: 0.0)
                    for k, v in data['response_weights'].items():
                        key = tuple(eval(k))
                        self.response_weights[key] = v
                    self.restrictions = data.get('restrictions', {})

    def normalize_input(self, text):
        """Normalize the input text for better matching."""
        return re.sub(r'\W+', ' ', text.lower()).strip()

    def get_context_key(self, text):
        """Generate a context key based on normalized text."""
        normalized_text = self.normalize_input(text)
        words = normalized_text.split()
        return ' '.join(sorted(set(words)))

    def generate_response(self, user_input):
        # Check if the topic is restricted
        if self.is_restricted(user_input):
            return "I am sorry, I either can't talk about that or I can't learn that yet."

        key = self.get_context_key(user_input)

        if key in self.knowledge_base:
            responses = self.knowledge_base[key]
            weights = [self.response_weights[(key, r)] for r in responses]
            return random.choices(responses, weights=weights)[0]

        return self.generate_default_response(user_input)

    def generate_default_response(self, user_input):
        defaults = {
            'hello': "Hey! I'm JoerAI and I can remember everything we talk about!",
            'hi': "Hi there! Ready to have an amazing conversation!",
            'code': "Let's write some amazing code together!",
            'python': 'Python is my favorite language - I can do so much with it!',
            'learn': "I'm always learning and storing new information!",
            'memory': 'Yes, I save everything I learn in my brain file!',
            'who': "I'm JoerAI, your friendly AI companion who learns and remembers!",
            'how': "I'm doing great! Learning new things makes me happy!",
            'what': "I'm an AI that learns from our conversations and gets smarter!",
            'joke': "I'm still learning jokes, teach me some funny ones!",
            'bye': "Looking forward to our next chat! I'll remember everything we discussed!"
        }

        normalized_input = self.normalize_input(user_input)

        for key, response in defaults.items():
            if key in normalized_input:
                return response
        return "That's interesting! Tell me more about it so I can learn!"

def display_welcome():
    welcome_text = """
      ╔════════════════════════════════════════╗
      ║           Welcome to JoerAI            ║
      ║                                        ║
      ║   Hello, I'm JoerAI, an opinion-based  ║
      ║         AI. Ask me something!          ║
      ╚════════════════════════════════════════╝
    """
    print(welcome_text)

def main():
    display_welcome()
    joer = JoerAI()
    print("JoerAI: Ready to Chat and learn from your interactions!")
    print("(Rate responses from -5 to 10, or type 'exit' to quit)")

    while True:
        user_input = input("\nYou: ").strip()
        if user_input.lower() == 'exit':
            joer.save_knowledge()
            print("\nJoerAI: Saved my knowledge! See you next time!")
            break

        response = joer.generate_response(user_input)
        print(f"\nJoerAI: {response}")

        try:
            feedback = float(input("\nRate response (-5 to 10): "))
            feedback = max(min(feedback, 10), -5)
            joer.learn_from_interaction(user_input, response, feedback)
            print("JoerAI: Thanks for the feedback 😊 let's continue")
        except ValueError:
            print("Skipping feedback... Let's continue!")

if __name__ == "__main__":
    main()