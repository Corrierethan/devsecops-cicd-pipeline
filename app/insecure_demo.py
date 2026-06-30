"""Intentionally insecure sample used to validate the SAST (Semgrep) gate.

This file is NOT imported by the application. It exists solely so the
pipeline's static analysis stage has a known-bad pattern to detect
(see issue #5). Do not use any of this code in production.
"""


def insecure_eval():
    # nosec - planted finding: eval on untrusted input (CWE-95).
    user_input = input("expression: ")
    return eval(user_input)  # noqa
