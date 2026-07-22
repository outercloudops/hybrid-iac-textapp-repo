import json
import pytest
from unittest.mock import patch, MagicMock
import lambda_handler as handler


# ── Helper ────────────────────────────────────────────────────────────────────

def make_event(question_id=1, question_weight="opening",
               question_text="test question", user_answer="test answer"):
    """
    Build a valid mock API Gateway event.
    Using a helper avoids repeating json.dumps() in every test.
    Default values mean most tests only need to override what they care about.
    """
    return {
        "body": json.dumps({
            "question_id":     question_id,
            "question_weight": question_weight,
            "question_text":   question_text,
            "user_answer":     user_answer,
        })
    }


def make_mock_response(text="A mocked reflection."):
    """Build a fake Anthropic response object."""
    mock = MagicMock()
    mock.content[0].text = text
    return mock


# ── Tests ─────────────────────────────────────────────────────────────────────

def test_handler_returns_200_on_valid_request():
    with patch.object(handler, "client") as mock_client:
        mock_client.messages.create.return_value = make_mock_response()
        response = handler.lambda_handler(make_event(), None)
    assert response["statusCode"] == 200


def test_handler_returns_response_key_in_body():
    with patch.object(handler, "client") as mock_client:
        mock_client.messages.create.return_value = make_mock_response()
        response = handler.lambda_handler(make_event(), None)
    body = json.loads(response["body"])
    assert "response" in body
    assert isinstance(body["response"], str)


def test_missing_body_returns_400():
    response = handler.lambda_handler({}, None)
    assert response["statusCode"] == 400


def test_missing_fields_returns_400():
    event = {"body": json.dumps({"question_id": 1})}
    response = handler.lambda_handler(event, None)
    assert response["statusCode"] == 400


def test_handler_strips_whitespace_from_response():
    with patch.object(handler, "client") as mock_client:
        mock_client.messages.create.return_value = make_mock_response(
            "  The founders agreed.  "
        )
        response = handler.lambda_handler(make_event(), None)
    body = json.loads(response["body"])
    assert body["response"] == "The founders agreed."


def test_correct_model_is_used():
    with patch.object(handler, "client") as mock_client:
        mock_client.messages.create.return_value = make_mock_response()
        handler.lambda_handler(make_event(), None)
        call_args = mock_client.messages.create.call_args
    assert call_args.kwargs["model"] == "claude-haiku-4-5-20251001"


def test_correct_token_limit_is_used():
    with patch.object(handler, "client") as mock_client:
        mock_client.messages.create.return_value = make_mock_response()
        handler.lambda_handler(make_event(), None)
        call_args = mock_client.messages.create.call_args
    assert call_args.kwargs["max_tokens"] == 280


def test_question_weight_is_passed_to_api():
    with patch.object(handler, "client") as mock_client:
        mock_client.messages.create.return_value = make_mock_response()
        handler.lambda_handler(
            make_event(question_id=8, question_weight="heavy"),
            None
        )
        call_args = mock_client.messages.create.call_args
    # Verify the weight label reached the user message
    user_message = call_args.kwargs["messages"][0]["content"]
    assert "heavy" in user_message
