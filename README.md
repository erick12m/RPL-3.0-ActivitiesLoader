# RPL 3.0 Activities Loader

A GitHub Action that automatically detects and uploads modified/created activities to the RPL 3.0. This action monitors changes in the `activities` directory and sends them to the RPL 3.0 Activities API.

## Overview

This actions do the following:

1. **Detects Changes**: Monitors the `activities` directory for any modified or created files
2. **Authenticates**: Logs into the RPL 3.0 platform using provided credentials
3. **Processes Activities**: Uploads activity data, files, and metadata to the platform
4. **Handles Categories**: Creates or updates activity categories as needed

## Activity Structure

Activities should be organized in the following structure:

```
activities/
├── {course_id}/
│   ├── {activity_name_unit_test}/
│   │   ├── activity.json
│   │   ├── files_metadata
│   │   └── unit_tests.*
│   │   └── {extra_files}
│   └── {activity_name_io_test}/
│   │   ├── activity.json
│   │   ├── files_metadata
│   │   └── io_tests.json
│   │   └── {extra_files}
```

### Required Files

- **`activity.json`**: Contains activity metadata
  ```json
  {
    "category_name": "Basic Programming",
    "category_description": "Fundamental programming exercises for beginners",
    "name": "Hello World",
    "description": "A simple Hello World program to get started with Python",
    "language": "python",
    "points": 100,
    "active": true
  }
  ```

- **`files_metadata`**: Defines the files permissions for students. Display can be: `read_only`, `read_write`, `hidden`. 
  ```json
  {
    "main.py": {
      "display": "read_write"
    }
  }
  ```
  
### Optional Files

It can be a unit test or IO test for each activity.

- **`unit_tests.*`**: A unit test for the activity. It can be any extension for supported languages, currently: `.py`, `rs`, `.c`, `.go`.
  ```python
  def test_basic_functionality():
    assert 1 + 1 == 2
  ```

- **`io_test.json`**: An IO test for the activity.
 ```json
 [
    {
      "name": "Test basic functionality",
      "test_in": "Hello World",
      "test_out": "Hello World"
    }
 ]
 ```


## Usage

Add this action to your workflow:

```yaml
name: Upload Activities to RPL 3.0

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  upload-activities:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 2  # Required to detect changes

      - name: Upload activities to RPL 3.0
        uses: erick12m/RPL-3.0-ActivitiesLoader@v1
        with:
          rpl_username: ${{ secrets.RPL_USERNAME }}
          rpl_password: ${{ secrets.RPL_PASSWORD }}
          activities_dir: activities # The directory containing the activities in the repository
```


## Required Secrets

You must set up the following secrets in your repository:

### `RPL_USERNAME`
 Your RPL 3.0 platform username

### `RPL_PASSWORD`
Your RPL 3.0 platform password


### Setting up Secrets

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret with the appropriate name and value

## How It Works

1. **Change Detection**: The action compares the current commit with the previous one to identify modified files in the activities directory
2. **Authentication**: Uses provided credentials to authenticate with the RPL 3.0 Users API
3. **Activity Processing**: For each changed activity:
   - Creates or updates the activity category
   - Uploads the activity metadata
   - Uploads associated files with proper metadata



## Troubleshooting

### Common Issues

1. **Authentication Failed**
   - Verify your `RPL_USERNAME` and `RPL_PASSWORD` secrets are correct
   - Ensure your account has the necessary permissions

2. **No Changes Detected**
   - Make sure you're using `fetch-depth: 2` in the checkout action
   - Verify changes are in the correct `activities` directory

3. **File Upload Failures**
   - Ensure activity files follow the required structure
   - Check that `activity.json` and `files_metadata` are properly formatted

## Manual Testing

You can test the action manually by running the following command:
```bash
./detect_changes.sh > changes.txt
cat changes.txt | RPL_USERNAME=your_username RPL_PASSWORD=your_password RPL_USERS_API_BASE_URL=http://localhost:30001 RPL_ACTIVITIES_API_BASE_URL=http://localhost:30001 ./process_activities_changes.sh
```

Ensure to use the correct credentials and API URLs for your RPL 3.0 local testing instance.
You can also use the changes.txt file directly to test the action.
