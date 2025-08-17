import sys
import os
import json
import uuid
import requests
import time
import hashlib
from datetime import datetime
from typing import Dict, Tuple, List, Set
import unittest
import shutil

class DirectoryMonitor:
    def __init__(self, base_directory: str):
        self.base_directory = base_directory
        self.file_states: Dict[str, Dict] = {}

    def get_file_hash(self, file_path: str) -> str:
        """Calculate MD5 hash of a file."""
        hash_md5 = hashlib.md5()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_md5.update(chunk)
        return hash_md5.hexdigest()

    def get_file_metadata(self, file_path: str) -> Dict:
        """Get file metadata including hash and size."""
        try:
            stat = os.stat(file_path)
            return {
                'hash': self.get_file_hash(file_path),
                'size': stat.st_size,
                'mtime': stat.st_mtime
            }
        except Exception as e:
            print(f"Warning: Could not get metadata for {file_path}: {str(e)}")
            return None

    def scan_directory(self) -> Dict[str, Dict]:
        """Scan directory and return file states."""
        file_states = {}
        for root, _, files in os.walk(self.base_directory):
            for file in files:
                file_path = os.path.join(root, file)
                relative_path = os.path.relpath(file_path, self.base_directory)
                metadata = self.get_file_metadata(file_path)
                if metadata:
                    file_states[relative_path] = metadata
        return file_states

    def compare_states(self, state1: Dict[str, Dict], state2: Dict[str, Dict]) -> Tuple[List[str], List[str], List[str]]:
        """Compare two directory states and return differences."""
        files1 = set(state1.keys())
        files2 = set(state2.keys())
        
        changed_files = []
        for file in files1 & files2:
            if state1[file]['hash'] != state2[file]['hash']:
                changed_files.append(file)
        
        added_files = list(files2 - files1)
        removed_files = list(files1 - files2)
        
        return changed_files, added_files, removed_files

class ApiDirectoryChangeTest(unittest.TestCase):
    def setUp(self):
        """Set up test environment."""
        self.api_url = "http://localhost:5004/backtest"
        self.headers = {"Content-Type": "application/json"}
        self.output_directory = "./App/SubtreeCache"
        
        # Create clean output directory
        if os.path.exists(self.output_directory):
            shutil.rmtree(self.output_directory)
        os.makedirs(self.output_directory)
        
        self.directory_monitor = DirectoryMonitor(self.output_directory)
        
        # Read both test JSON files
        try:
            with open("./App/Tests/TestsJSON/SmokeTestsJSON/Subtreecall1.json", "r", encoding="utf-8") as file:
                self.json_data1 = file.read()
            with open("./App/Tests/TestsJSON/SmokeTestsJSON/Subtreecall2.json", "r", encoding="utf-8") as file:
                self.json_data2 = file.read()
        except Exception as e:
            self.fail(f"Failed to read test JSON files: {str(e)}")

    def generate_hash(self) -> str:
        return str(uuid.uuid4())

    def make_api_call(self, json_data: str, hash_value: str) -> requests.Response:
        """Make an API call with the given JSON data and hash."""
        try:
            print(f"Making API call with hash: {hash_value} on api url: {self.api_url}")
            response = requests.post(
                self.api_url,
                data=json.dumps({
                    "json": json_data,
                    "period": "5000",
                    "hash": hash_value,
                    "end_date": "2024-09-30"
                }),
                headers=self.headers
            )
            response.raise_for_status()
            return response
        except requests.exceptions.RequestException as e:
            self.fail(f"API call failed: {str(e)}")

    def test_directory_changes_with_different_jsons(self):
        """Test that verifies directory files don't change between API calls with different JSONs."""
        # First API call with test1.json
        print("\nMaking first API call with test1.json...")
        first_hash = self.generate_hash()
        first_response = self.make_api_call(self.json_data1, first_hash)
        self.assertEqual(first_response.status_code, 200, "First API call failed")
        
        # Wait for files to be created
        time.sleep(5)  # Adjust wait time as needed
        
        # Get initial state after first API call
        initial_state = self.directory_monitor.scan_directory()
        
        # Verify that files were created
        self.assertTrue(initial_state, "No files were created after first API call")
        print(f"\nFiles created after first call (test1.json): {list(initial_state.keys())}")
        
        # Second API call with test2.json
        print("\nMaking second API call with test2.json...")
        second_hash = self.generate_hash()
        second_response = self.make_api_call(self.json_data2, second_hash)
        self.assertEqual(second_response.status_code, 200, "Second API call failed")
        
        # Wait for potential file changes
        time.sleep(5)  # Adjust wait time as needed
        
        # Get final state
        final_state = self.directory_monitor.scan_directory()
        
        # Compare states
        changed_files, added_files, removed_files = self.directory_monitor.compare_states(
            initial_state, final_state
        )
        
        # Print detailed results
        print("\nTest Results:")
        print(f"Files present after first call : {list(initial_state.keys())}")
        print(f"Files present after second call : {list(final_state.keys())}")
        print(f"Changed files: {changed_files}")
        print(f"Added files: {added_files}")
        print(f"Removed files: {removed_files}")
        
        # Assert conditions
        test_passed = not changed_files  and not removed_files
        
        # Detailed failure message
        if not test_passed:
            failure_message = (
                f"Test failed: Directory contents changed between API calls\n"
                f"First API call hash: {first_hash}\n"
                f"Second API call hash: {second_hash}\n"
                f"Changed files: {changed_files}\n"
                f"Added files: {added_files}\n"
                f"Removed files: {removed_files}\n"
                f"Initial state files: {list(initial_state.keys())}\n"
                f"Final state files: {list(final_state.keys())}"
            )
            self.fail(failure_message)

    def tearDown(self):
        """Clean up after test."""
        if os.path.exists(self.output_directory):
            shutil.rmtree(self.output_directory)

def run_tests():
    """Run the API directory change tests."""
    # Create test suite
    suite = unittest.TestLoader().loadTestsFromTestCase(ApiDirectoryChangeTest)
    
    # Run tests with detailed output
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Return True if all tests passed, False otherwise
    return result.wasSuccessful()

if __name__ == "__main__":
    try:
        success = run_tests()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"Test execution failed: {str(e)}")
        sys.exit(1)
