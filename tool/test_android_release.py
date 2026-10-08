"""Exercise release metadata through the same CLI used by GitHub Actions."""

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("android_release.py")


class ReleaseMetadataTest(unittest.TestCase):
    def run_metadata(self, tag="v1.0.1", run="7", offset="1", version="1.0.0+1"):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "pubspec.yaml").write_text(f"name: example\nversion: {version}\n")
            output = root / "output"
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "metadata"],
                cwd=root,
                env={
                    "RELEASE_TAG": tag,
                    "GITHUB_RUN_NUMBER": run,
                    "BUILD_OFFSET": offset,
                    "GITHUB_OUTPUT": str(output),
                },
                capture_output=True,
                text=True,
            )
            return result, output.read_text() if output.exists() else ""

    def test_tag_overrides_local_version(self):
        result, output = self.run_metadata()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output, "version=1.0.1\nbuild_number=8\n")

    def test_first_run_and_rerun_have_same_build(self):
        for _ in range(2):
            result, output = self.run_metadata(run="1")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(output, "version=1.0.1\nbuild_number=2\n")

    def test_invalid_tag_is_rejected(self):
        result, output = self.run_metadata(tag="v1.0.1-beta")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Release tag must be", result.stderr)
        self.assertEqual(output, "")

    def test_invalid_build_numbers_are_rejected(self):
        for run, offset in [("0", "1"), ("1", "-1"), ("1", "0"),
                            ("2100000000", "1"), ("abc", "1")]:
            with self.subTest(run=run, offset=offset):
                result, output = self.run_metadata(run=run, offset=offset)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(output, "")

    def test_malformed_local_version_is_rejected(self):
        result, output = self.run_metadata(version="1.0.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("pubspec.yaml version must be", result.stderr)
        self.assertEqual(output, "")

class KeystoreRestoreTest(unittest.TestCase):
    def restore(self, encoded, existing=False):
        import os
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            key = root / 'release.jks'
            if existing:
                key.write_bytes(b'original')
            result = subprocess.run(
                [sys.executable, str(SCRIPT), 'keystore'],
                env={
                    'ANDROID_KEYSTORE_BASE64': encoded,
                    'ANDROID_KEYSTORE_PASSWORD': 'test-store-password',
                    'ANDROID_KEY_ALIAS': 'test-alias',
                    'ANDROID_KEY_PASSWORD': 'test-key-password',
                    'ANDROID_KEYSTORE_PATH': str(key),
                }, capture_output=True, text=True,
            )
            return result, key.read_bytes() if key.exists() else None, (os.stat(key).st_mode & 0o777) if key.exists() else None

    def test_restore_bytes_with_private_permissions(self):
        result, data, mode = self.restore('dGVzdC1rZXk=')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(data, b'test-key')
        self.assertEqual(mode, 0o600)
        self.assertNotIn('test-store-password', result.stdout + result.stderr)
        self.assertNotIn('test-key-password', result.stdout + result.stderr)

    def test_invalid_base64_leaves_no_key(self):
        result, data, _ = self.restore('not-base64!')
        self.assertNotEqual(result.returncode, 0)
        self.assertIsNone(data)

    def test_existing_key_cannot_be_overwritten(self):
        result, data, _ = self.restore('dGVzdC1rZXk=', existing=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(data, b'original')


if __name__ == "__main__":
    unittest.main()
