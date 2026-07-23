"""
conftest.py — pytest configuration for the Founding Mirror test suite.

Adds the ah-text-app/ directory to sys.path so that the test file can
import lambda_handler directly regardless of where pytest is invoked from.

Place this file at: ah-text-app/tests/conftest.py
"""

import sys
import os

# Insert the parent directory (ah-text-app/) into sys.path.
# This allows: import lambda_handler as handler
# to resolve to ah-text-app/lambda_handler.py from any working directory.
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
