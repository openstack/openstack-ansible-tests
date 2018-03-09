import unittest

from ansiblelint import RulesCollection, Runner
from APTRepositoryCacheUpdateRule import APTRepositoryCacheUpdateRule


class TestAPTRepositoryCacheUpdateRule(unittest.TestCase):
    collection = RulesCollection()

    def setUp(self):
        self.collection.register(APTRepositoryCacheUpdateRule())

    def test_file_positive(self):
        success = 'ansible-lint/test/apt-repository-cache-update-success.yml'
        good_runner = Runner(self.collection, success, [], [], [])
        self.assertEqual([], good_runner.run())

    def test_file_negative(self):
        failure = 'ansible-lint/test/apt-repository-cache-update-failure.yml'
        bad_runner = Runner(self.collection, failure, [], [], [])
        errs = bad_runner.run()
        self.assertEqual(4, len(errs))
