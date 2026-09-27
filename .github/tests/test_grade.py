"""Guard the scoring adapter against incomplete and unsuccessful executions."""

from copy import deepcopy
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import grade


class GradingTests(unittest.TestCase):
    def test_catalog_must_match_all_upstream_exercises(self):
        grade.validate_catalog()
        altered = deepcopy(grade.COURSE)
        altered["tests"].pop()
        with patch.object(grade, "COURSE", altered):
            with self.assertRaisesRegex(ValueError, "catalog differs"):
                grade.validate_catalog()

    def test_test_and_buildscript_need_executed_tests(self):
        for mode in ("test", "buildscript"):
            exercise = {"mode": mode}
            self.assertFalse(grade.passed(exercise, 0, "test result: ok. 0 passed; 0 failed;"))
            self.assertFalse(grade.passed(exercise, 0, ""))
            output = "test result: ok. 2 passed; 0 failed; 0 ignored;"
            self.assertTrue(grade.passed(exercise, 0, output))
            self.assertFalse(grade.passed(exercise, 1, output))

    def test_compile_and_clippy_require_success_for_the_requested_exercise(self):
        for mode in ("compile", "clippy"):
            exercise = {"mode": mode, "path": "exercises/example.rs"}
            self.assertTrue(grade.passed(exercise, 0, "Successfully ran exercises/example.rs"))
            self.assertFalse(grade.passed(exercise, 0, "Successfully ran exercises/other.rs"))
            self.assertFalse(grade.passed(exercise, 124, "Successfully ran exercises/example.rs"))


if __name__ == "__main__":
    unittest.main()
