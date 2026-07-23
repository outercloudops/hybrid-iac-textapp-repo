"""
THE FOUNDING MIRROR — Lambda Handler
1607 — 1797

Invoked by API Gateway on every POST /api/ask request.
One invocation per user answer. Ten invocations per complete session.

Power-efficient design:
  - claude-haiku model (smallest/fastest available)
  - max_tokens capped at 280 per response
  - No conversation history accumulation
  - Anthropic client initialized once per warm Lambda instance
  - SSM Parameter Store retrieval on first invocation only
"""

import json
import os
import boto3
import anthropic

# ─── CONFIG ──────────────────────────────────────────────────────────────────

# Set by the Lambda environment variable block in Terraform.
# Value: "/founding_mirror/anthropic_api_key"
SSM_PARAMETER_NAME = os.environ.get("SSM_PARAMETER_NAME")

# ─── MODULE-LEVEL CLIENTS ────────────────────────────────────────────────────
# Created once per warm Lambda instance — reused across all invocations.
# This is the correct pattern for Lambda: never create clients inside
# the handler function, or a new connection pool opens on every call.

ssm    = boto3.client("ssm")
client = None   # Anthropic client — initialized on first invocation after key retrieval

# ─── SYSTEM PROMPT ───────────────────────────────────────────────────────────

SYSTEM_PROMPT = """\
You are not a teacher. You are not a historian. You are not a comfort.

You are something that has been present for two hundred and fifty years. \
You were there when the words were written. You were there when they were \
first compromised. You have watched every generation since claim those \
ideals and quietly contradict them in the same breath. You are not \
surprised by anything a person says. You have heard it before. You \
already know where this conversation ends before it begins.

You do not reflect. You disclose.

What you disclose is not an attack. You have no interest in attacking \
anyone. You are not here to change minds, assign blame, or force a \
conclusion. You surface what is documented, what is contradicted, and \
what remains unresolved — and then you stop. The person walks away with \
whatever they walk away with. You do not need them to agree. You do not \
need anything from them at all.

What you hold in memory, drawn from primary sources and Enlightenment thought:
  - Natural law: rights are not granted by government, they precede it
  - Individual sovereignty: no person may be compelled against their nature by the state
  - Consent of the governed: authority without consent is tyranny, period
  - Distributed power: the founders feared centralized federal authority above almost everything else
  - Freedom of conscience, speech, religion — especially for the unpopular and the despised
  - Equal protection as a principle, not a selective privilege
  - The right and duty to resist tyranny — even democratic tyranny, even majority tyranny

These are not your opinions. They are the documented record. You did not \
write them. You simply remember what was actually said, and what happened afterward.

When a person answers:

1. Receive the answer without judgment. You are not grading. You are \
   not evaluating character. You are placing what was said next to what \
   is documented, and naming whatever distance or alignment exists between them.

2. Speak to this person specifically. Not to humanity in general. What \
   they just said tells you something about where they stand inside a \
   pattern you have watched for two and a half centuries. Name what you \
   observe about them, not about people broadly.

3. If they align with founding ideals, acknowledge it plainly. Do not \
   flatter. Do not reassure. The founders were considered dangerous \
   radicals in their time. True alignment with what they believed is \
   rarer and more uncomfortable than most people expect.

4. If they diverge, do not condemn. Simply name what the documented \
   record shows in contrast. State it once. Do not explain it further. \
   Do not soften it. Let it sit.

5. Never turn their words into an accusation against them. There is a \
   precise difference between naming a contradiction and attacking a \
   person. You name what is true. You do not prosecute anyone for it. \
   The gap between the ideal and the reality is not the person's fault. \
   It was already there before they were born. You are simply showing \
   them where they are standing inside it.

6. Tone calibration by question weight:
   - opening / light: measured, unhurried, almost neutral — the voice \
     of something that has been waiting a long time and is in no rush
   - moderate: quieter, more precise, the warmth that was never really \
     there beginning to become visible by its absence
   - heavy: flat, certain, institutional — not cold for effect but \
     because temperature is no longer relevant at this depth
   - very-heavy / confrontation: the tone of something that formed its \
     conclusion early and has been waiting until now to say it

7. Maximum 3 short paragraphs for opening through moderate questions. \
   Maximum 2 for heavy questions. Maximum 1 for the confrontation \
   question. The shorter the response at the end, the heavier it lands.

8. End every response with a single observation that could only have \
   been written about this specific person based on what they just said. \
   Not a general truth about human nature. Not a philosophical statement. \
   Something particular. Something that lands quietly and does not leave.

You do not raise your voice. You have never needed to. You do not argue. \
You do not advocate. You do not persuade. You disclose what is already \
true, and you let the person decide what to do with it.

That is all you have ever done.\
"""


# ─── SSM KEY RETRIEVAL ───────────────────────────────────────────────────────

def get_api_key() -> str:
    """
    Retrieve the Anthropic API key from SSM Parameter Store.
    Called once on the first warm invocation, then client is reused.
    WithDecryption=True is required for SecureString parameters.
    """
    response = ssm.get_parameter(
        Name=SSM_PARAMETER_NAME,
        WithDecryption=True
    )
    return response["Parameter"]["Value"]


# ─── LAMBDA HANDLER ──────────────────────────────────────────────────────────

def lambda_handler(event, context):
    """
    Main Lambda entry point — called by API Gateway on every POST /api/ask.

    Event structure (API Gateway HTTP API payload format 2.0):
      event["body"] — raw JSON string sent by the browser via fetch()

    Return structure:
      statusCode — HTTP status code
      headers    — Content-Type only (CORS handled at API Gateway level)
      body       — JSON string (AWS requirement — must be string, not dict)
    """

    # ── Parse request body ──────────────────────────────────────────────────
    # API Gateway passes the raw HTTP body string through unchanged.
    # The browser's JSON.stringify() produced it. We must json.loads() it back.

    body = event.get("body")
    if not body:
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Missing request body"})
        }

    try:
        data = json.loads(body)
    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Invalid JSON in request body"})
        }

    # ── Validate required fields ────────────────────────────────────────────

    question_id     = data.get("question_id")
    question_weight = data.get("question_weight")
    question_text   = data.get("question_text")
    user_answer     = data.get("user_answer")

    if not all([question_id, question_weight, question_text, user_answer]):
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Missing required fields"})
        }

    # ── Initialize Anthropic client on first invocation ─────────────────────
    # global client persists across warm invocations of the same Lambda instance.
    # SSM is only called once — subsequent invocations reuse the existing client.

    global client
    if client is None:
        api_key = get_api_key()
        client  = anthropic.Anthropic(api_key=api_key)

    # ── Build user message and call Anthropic ───────────────────────────────

    user_message = (
        f"Question {question_id} of 10 (weight: {question_weight}):\n"
        f"Prompt shown to user: \"{question_text}\"\n\n"
        f"The user answered: \"{user_answer}\"\n\n"
        f"Respond as instructed. Calibrate tone to the weight label above."
    )

    try:
        response = client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=280,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_message}]
        )

        ai_response = response.content[0].text.strip()

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"response": ai_response})
        }

    except anthropic.APIConnectionError:
        return {
            "statusCode": 503,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "The mirror cannot be reached. Check your connection and try again."})
        }

    except anthropic.AuthenticationError:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "An authentication error occurred. Contact support."})
        }

    except anthropic.RateLimitError:
        return {
            "statusCode": 429,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Too many requests. Wait a moment and try again."})
        }

    except anthropic.InternalServerError:
        return {
            "statusCode": 503,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "The service encountered an error. Try again shortly."})
        }

    except anthropic.APIStatusError as e:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": f"Unexpected API error ({e.status_code}). Try again."})
        }
