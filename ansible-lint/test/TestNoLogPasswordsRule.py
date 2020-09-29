import unittest

from ansiblelint.rules import RulesCollection
from ansiblelint.runner import Runner
from NoLogPasswordsRule import NoLogPasswordsRule


class TestNoLogPasswordsRule(unittest.TestCase):
    collection = RulesCollection()

    def setUp(self):
        self.collection.register(NoLogPasswordsRule())

    def test_file_positive(self):
        success = 'ansible-lint/test/no-log-passwords-success.yml'
        good_runner = Runner(self.collection, success, [], [], [])
        self.assertEqual([], good_runner.run())

    def test_file_negative(self):
        failure = 'ansible-lint/test/no-log-passwords-failure.yml'
        bad_runner = Runner(self.collection, failure, [], [], [])
        errs = bad_runner.run()
        self.assertEqual(3, len(errs))
