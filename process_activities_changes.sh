#!/bin/bash

# Config
API_BASE_URL="${API_BASE_URL:-http://192.168.49.2:30002}"
USERS_API_BASE_URL="${USERS_API_BASE_URL:-http://192.168.49.2:30001}"
RPL_USERNAME="${RPL_USERNAME:-testadmin}"
RPL_PASSWORD="${RPL_PASSWORD:-test}"
AUTH_TOKEN=""

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NO_COLOR='\033[0m' 

log_info() {
    echo -e "${BLUE}[INFO]${NO_COLOR} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NO_COLOR} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NO_COLOR} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NO_COLOR} $1" >&2
}

auth_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local content_type="${4:-application/json}"
    
    local url="${USERS_API_BASE_URL}${endpoint}"
    local response
    
    response=$(curl -s -X "$method" \
        -H "Content-Type: $content_type" \
        -H "Accept: application/json" \
        -d "$data" \
        "$url" || echo "")
    
    if [[ -z "$response" ]]; then
        log_error "Failed to connect to users API at ${USERS_API_BASE_URL}"
        return 1
    fi
    
    echo "$response"
    return 0
}

multipart_api_request() {
    local method="$1"
    local endpoint="$2"
    local form_data_array_name="$3"
    
    local url="${API_BASE_URL}${endpoint}"
    local response
    local http_code
    
    local -n form_data_ref="$form_data_array_name"
    
    response=$(curl -s -w "%{http_code}" -X "$method" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -H "Accept: application/json" \
        "${form_data_ref[@]}" \
        "$url")
    
    http_code="${response: -3}"
    response="${response%???}"
    
    # Success
    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        echo "$response"
        return 0
    else
        return 1
    fi
}

check_env() {
    if [[ -z "$RPL_USERNAME" ]]; then
        log_error "Username is required"
        exit 1
    fi
    
    if [[ -z "$RPL_PASSWORD" ]]; then
        log_error "Password is required"
        exit 1
    fi
    
    log_info "Env validated"
}

authenticate() {
    log_info "Authenticating with RPL-Users API"
    
    local auth_data=$(jq -n \
        --arg username_or_email "$RPL_USERNAME" \
        --arg password "$RPL_PASSWORD" \
        '{username_or_email: $username_or_email, password: $password}')
    
    local response
    if ! response=$(auth_request "POST" "/api/v3/auth/login" "$auth_data"); then
        exit 1
    fi
    
    # Check for error in response
    local error_detail
    error_detail=$(echo "$response" | jq -r '.detail // empty' 2>/dev/null || echo "")
    
    if [[ -n "$error_detail" ]]; then
        log_error "Authentication failed: $error_detail"
        exit 1
    fi
    
    # Extract token
    AUTH_TOKEN=$(echo "$response" | jq -r '.access_token // empty' 2>/dev/null || echo "")
    
    if [[ -z "$AUTH_TOKEN" ]]; then
        log_error "Failed to extract access token from response"
        exit 1
    fi
    
    log_success "Authentication successful"
}

api_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local content_type="${4:-application/json}"
    
    local url="${API_BASE_URL}${endpoint}"

    local response
    local http_code
    
    if [[ "$method" == "GET" ]]; then
        response=$(curl -s -w "%{http_code}" -X "$method" \
            -H "Authorization: Bearer $AUTH_TOKEN" \
            -H "Accept: application/json" \
            "$url")
    else
        response=$(curl -s -w "%{http_code}" -X "$method" \
            -H "Authorization: Bearer $AUTH_TOKEN" \
            -H "Content-Type: $content_type" \
            -H "Accept: application/json" \
            -d "$data" \
            "$url")
    fi

    http_code="${response: -3}"
    response="${response%???}"
    
    # Success
    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
    echo "$response"
        return 0
    else
        return 1
    fi
}

get_existing_categories() {
    local course_id="$1"
    log_info "Fetching existing categories for course $course_id"
    api_request "GET" "/api/v3/courses/$course_id/activityCategories"
}

create_category() {
    local course_id="$1"
    local name="$2"
    local description="$3"
    
    log_info "Creating category: $name for course $course_id"
    
    local data=$(jq -n \
        --arg name "$name" \
        --arg description "$description" \
        '{
            name: $name,
            description: $description
        }')
    
    api_request "POST" "/api/v3/courses/$course_id/activityCategories" "$data"
}

update_category() {
    local course_id="$1"
    local category_id="$2"
    local name="$3"
    local description="$4"
    local active="${5:-true}"
    
    log_info "Updating category: $name (ID: $category_id) for course $course_id"
    
    local data=$(jq -n \
        --arg name "$name" \
        --arg description "$description" \
        --argjson active "$active" \
        '{
            name: $name,
            description: $description,
            active: $active
        }')
    
    api_request "PATCH" "/api/v3/courses/$course_id/activityCategories/$category_id" "$data"
}

# Check if category exists, create it it's not already created
analyze_category() {
    local course_id="$1"
    local category_name="$2"
    local category_description="${3:-$category_name}"
    
    # Get existing categories
    local existing_categories=$(get_existing_categories "$course_id")
    
    # Check if category already exist
    local category_id=$(echo "$existing_categories" | jq -r ".[] | select(.name == \"$category_name\") | .id" | head -1)
    
    if [[ -n "$category_id" && "$category_id" != "null" ]]; then
        log_info "Found existing category '$category_name' with ID: $category_id"
        echo "$category_id"
        return 0
    fi
    
    # Category don't exist, create it
    log_info "Category '$category_name' not found, creating it"
    
    
    local response=$(create_category "$course_id" "$category_name" "$category_description")
    
    if [[ $? -eq 0 ]]; then
        local new_category_id=$(echo "$response" | jq -r '.id')
        log_success "Created category '$category_name' with ID: $new_category_id"
        echo "$new_category_id"
        return 0
    else
        log_error "Failed to create category: $category_name"
        return 1
    fi
}

get_existing_activities() {
    local course_id="$1"
    log_info "Fetching existing activities for course $course_id"
    api_request "GET" "/api/v3/courses/$course_id/activities"
}

get_activity_details() {
    local course_id="$1"
    local activity_id="$2"
    api_request "GET" "/api/v3/courses/$course_id/activities/$activity_id"
}

create_activity() {
    local course_id="$1"
    local category_id="$2"
    local name="$3"
    local description="$4"
    local language="$5"
    local points="$6"
    local active="$7"
    local compilation_flags="$8"
    local activity_dir="$9"
    
    log_info "Creating activity: $name for course $course_id"
    
    local form_data=(-F "category_id=$category_id")
    form_data+=(-F "name=$name")
    form_data+=(-F "description=$description")
    form_data+=(-F "language=$language")
    form_data+=(-F "points=$points")
    form_data+=(-F "active=$active")
    
    if [[ -n "$compilation_flags" ]]; then
        form_data+=(-F "compilation_flags=$compilation_flags")
    fi
    
    # Add files to form_data array
    while IFS= read -r -d '' file; do
        local filename=$(basename "$file")
        if [[ "$filename" != "activity.json" && "$filename" != "io_tests.json" && "$filename" != "unit_tests.txt" ]]; then
            form_data+=(-F "startingFile=@$file")
        fi
    done < <(find "$activity_dir" -type f -print0)
    
    local response
    if response=$(multipart_api_request "POST" "/api/v3/courses/$course_id/activities" "form_data"); then
        echo "$response"
        return 0
    else
        log_error "Failed to create activity: $name"
        return 1
    fi
}

update_activity() {
    local course_id="$1"
    local activity_id="$2"
    local category_id="$3"
    local name="$4"
    local description="$5"
    local language="$6"
    local points="$7"
    local active="$8"
    local compilation_flags="$9"
    local activity_dir="${10}"
    
    log_info "Updating activity: $name (ID: $activity_id) for course $course_id"
    
    local form_data=(-F "category_id=$category_id")
    form_data+=(-F "name=$name")
    form_data+=(-F "description=$description")
    form_data+=(-F "language=$language")
    form_data+=(-F "points=$points")
    form_data+=(-F "active=$active")
    
    if [[ -n "$compilation_flags" ]]; then
        form_data+=(-F "compilation_flags=$compilation_flags")
    fi
    
    # Add files to form_data array
    if [[ -n "$activity_dir" ]]; then
        while IFS= read -r -d '' file; do
            local filename=$(basename "$file")
            if [[ "$filename" != "activity.json" && "$filename" != "io_tests.json" && "$filename" != "unit_tests.txt" ]]; then
                form_data+=(-F "startingFile=@$file")
            fi
        done < <(find "$activity_dir" -type f -print0)
    fi
    
    local response
    if response=$(multipart_api_request "PATCH" "/api/v3/courses/$course_id/activities/$activity_id" "form_data"); then
        echo "$response"
        return 0
    else
        log_error "Failed to update activity: $name"
        return 1
    fi
}

process_io_tests() {
    local course_id="$1"
    local activity_id="$2"
    local activity_dir="$3"
    local io_tests_file="$activity_dir/io_tests.json"
    
    if [[ ! -f "$io_tests_file" ]]; then
        log_info "No IO tests file found for activity"
        return 0
    fi
    
    local activity_details=$(get_activity_details "$course_id" "$activity_id")
    local unit_tests_data=$(echo "$activity_details" | jq -r '.activity_unittests // empty')
    if [[ -n "$unit_tests_data" ]]; then
        log_warning "Activity: $name has unit tests. Cannot add IO tests."
        return 0
    fi
    
    log_info "Processing IO tests from $io_tests_file"
    
    local existing_tests=$(echo "$activity_details" | jq -r '.activity_iotests // []')
    
    # Read and process each io_test
    local test_count=$(jq '. | length' "$io_tests_file")
    for ((i=0; i<test_count; i++)); do
        local test_data=$(jq ".[$i]" "$io_tests_file")
        local test_name=$(echo "$test_data" | jq -r '.name')
        local test_in=$(echo "$test_data" | jq -r '.test_in')
        local test_out=$(echo "$test_data" | jq -r '.test_out')
        
        # Check if test already exists (match by name)
        local existing_test_id=$(echo "$existing_tests" | jq -r ".[] | select(.name == \"$test_name\") | .id")
        
        if [[ -n "$existing_test_id" && "$existing_test_id" != "null" ]]; then
            # Update existing IO test
            log_info "Updating IO test: $test_name"
            if local response=$(update_io_test "$course_id" "$activity_id" "$existing_test_id" "$test_name" "$test_in" "$test_out"); then
                log_success "Updated IO test: $test_name"
            else
                log_error "Failed to update IO test: $test_name"
                return 1
            fi
        else
            # Create new IO test
            log_info "Creating IO test: $test_name"
            if local response=$(create_io_test "$course_id" "$activity_id" "$test_name" "$test_in" "$test_out"); then
                log_success "Created IO test: $test_name"
            else
                log_error "Failed to create IO test: $test_name"
                return 1
            fi
        fi
    done
    
    return 0
}

process_unit_tests() {
    local course_id="$1"
    local activity_id="$2"
    local activity_dir="$3"
    local unit_tests_file="$activity_dir/unit_tests.txt"
    
    if [[ ! -f "$unit_tests_file" ]]; then
        log_info "No unit tests file found for activity"
        return 0
    fi
    
    # Check if activity has IO tests
    local activity_details=$(get_activity_details "$course_id" "$activity_id")
    local has_io_tests=$(echo "$activity_details" | jq -r '.activity_iotests | length > 0')
    
    if [[ "$has_io_tests" == "true" ]]; then
        log_warning "Activity: $name has IO tests. Cannot add unit tests."
        return 0
    fi
    
    log_info "Processing unit tests from $unit_tests_file"
    
    local unit_test_code=$(cat "$unit_tests_file")
    
    # Check if unit tests already exist
    local activity_unit_tests=$(echo "$activity_details" | jq -r '.activity_unittests // empty')
    local has_unit_tests="false"
    if [[ -n "$activity_unit_tests" ]]; then
        has_unit_tests="true"
    fi
    
    if [[ "$has_unit_tests" == "true" ]]; then
        log_info "Updating unit tests"
        if local response=$(update_unit_tests "$course_id" "$activity_id" "$unit_test_code"); then
            log_success "Updated unit tests"
        else
            log_error "Failed to update unit tests"
            return 1
        fi
    else
        log_info "Creating unit tests"
        if local response=$(create_unit_tests "$course_id" "$activity_id" "$unit_test_code"); then
            log_success "Created unit tests"
        else
            log_error "Failed to create unit tests"
            return 1
        fi
    fi
    
    return 0
}

create_io_test() {
    local course_id="$1"
    local activity_id="$2"
    local name="$3"
    local test_in="$4"
    local test_out="$5"
    
    local data=$(jq -n \
        --arg name "$name" \
        --arg test_in "$test_in" \
        --arg test_out "$test_out" \
        '{
            name: $name,
            test_in: $test_in,
            test_out: $test_out
        }')
    
    api_request "POST" "/api/v3/courses/$course_id/activities/$activity_id/iotests" "$data"
}

update_io_test() {
    local course_id="$1"
    local activity_id="$2"
    local io_test_id="$3"
    local name="$4"
    local test_in="$5"
    local test_out="$6"
    
    local data=$(jq -n \
        --arg name "$name" \
        --arg test_in "$test_in" \
        --arg test_out "$test_out" \
        '{
            name: $name,
            test_in: $test_in,
            test_out: $test_out
        }')
    
    api_request "PUT" "/api/v3/courses/$course_id/activities/$activity_id/iotests/$io_test_id" "$data"
}

create_unit_tests() {
    local course_id="$1"
    local activity_id="$2"
    local unit_test_code="$3"
    
    local data=$(jq -n \
        --arg code "$unit_test_code" \
        '{
            unit_test_code: $code
        }')
    
    api_request "POST" "/api/v3/courses/$course_id/activities/$activity_id/unittests" "$data"
    
}

update_unit_tests() {
    local course_id="$1"
    local activity_id="$2"
    local unit_test_code="$3"
    
    local data=$(jq -n \
        --arg code "$unit_test_code" \
        '{
            unit_test_code: $code
        }')
    
    api_request "PUT" "/api/v3/courses/$course_id/activities/$activity_id/unittests" "$data"
}

process_activity() {
    local course_id="$1"
    local activity_dir="$2"
    local activity_name=$(basename "$activity_dir")
    
    log_info "Processing activity: $activity_name in course $course_id"
    
    local activity_json="$activity_dir/activity.json"
    if [[ ! -f "$activity_json" ]]; then
        log_error "activity.json not found in $activity_dir"
        return 1
    fi
    
    local name=$(jq -r '.name' "$activity_json")
    if [[ "$name" == "null" ]]; then
        log_error "Missing required field 'name' in $activity_json"
        return 1
    fi
    
    local category_name=$(jq -r '.category_name // .category' "$activity_json")
    local category_description=$(jq -r '.category_description // ""' "$activity_json")
    local description=$(jq -r '.description // ""' "$activity_json")
    local language=$(jq -r '.language' "$activity_json")
    local points=$(jq -r '.points // 100' "$activity_json")
    local active=$(jq -r '.active // true' "$activity_json")
    local compilation_flags=$(jq -r '.compilation_flags // ""' "$activity_json")

    
    # required fields
    if [[ "$category_name" == "null" || "$language" == "null" ]]; then
        log_error "Missing required fields in $activity_json (category_name or category, language)"
        return 1
    fi
    
    local category_id
    if ! category_id=$(analyze_category "$course_id" "$category_name" "$category_description"); then
        log_error "Failed to resolve category: $category_name for activity in $activity_dir" 
        return 1
    fi
    
    # Check if activity  exists
    local existing_activities=$(get_existing_activities "$course_id")
    local activity_id=$(echo "$existing_activities" | jq -r ".[] | select(.name == \"$name\") | .id" | head -1)
    
    # Create or update activity
    local activity_response
    if [[ -n "$activity_id" && "$activity_id" != "null" ]]; then
        # Update existing activity
        if activity_response=$(update_activity "$course_id" "$activity_id" "$category_id" "$name" "$description" "$language" "$points" "$active" "$compilation_flags" "$activity_dir"); then
            log_success "Updated activity: $name"
        else
            log_error "Failed to update activity: $name in $activity_dir"
            return 1
        fi
    else
        # Create new activity
        if activity_response=$(create_activity "$course_id" "$category_id" "$name" "$description" "$language" "$points" "$active" "$compilation_flags" "$activity_dir"); then
            log_success "Created activity: $name"
            activity_id=$(echo "$activity_response" | jq -r '.id')
            if [[ "$activity_id" == "null" || -z "$activity_id" ]]; then
                log_error "Failed to extract activity ID from response for activity in $activity_dir"
                return 1
            fi
        else
            log_error "Failed to create activity: $name in $activity_dir"
            return 1
        fi
    fi
    
    local has_io_tests=false
    local has_unit_tests=false
    
    if [[ -f "$activity_dir/io_tests.json" ]]; then
        has_io_tests=true
    fi
    
    if [[ -f "$activity_dir/unit_tests.txt" ]]; then
        has_unit_tests=true
    fi
    
    # Check if both test types are present
    if [[ "$has_io_tests" == "true" && "$has_unit_tests" == "true" ]]; then
        log_warning "Activity: $name in $activity_dir has both IO tests and unit tests."
        log_warning "Processing IO tests first - unit tests will be ignored."
        log_warning "Create a new activity for unit test."
        has_unit_tests=false
    fi
    
    if [[ "$has_io_tests" == "true" ]]; then
        log_info "Processing IO tests for: $name"
        if ! process_io_tests "$course_id" "$activity_id" "$activity_dir"; then
            log_error "Failed to process IO tests for: $name in $activity_dir"
            return 1
        fi
    elif [[ "$has_unit_tests" == "true" ]]; then
        log_info "Processing unit tests for: $name"
        if ! process_unit_tests "$course_id" "$activity_id" "$activity_dir"; then
            log_error "Failed to process unit tests for: $name in $activity_dir"
            return 1
        fi
    else
        log_info "No test files found for: $name"
    fi
    
    log_info "Completed processing activity: $name"
    return 0
}

main() {
    log_info "Starting RPL Activities Processing"
    
    check_env
    authenticate
    
    # Read changed files from stdin or as arguments
    local changed_files_input=""
    if [[ $# -eq 0 ]]; then
        # Read from stdin
        changed_files_input=$(cat)
    else
        # Use arguments (for testing or manual runs)
        changed_files_input=$(printf "%s\n" "$@")
    fi
    
    if [[ -z "$changed_files_input" ]]; then
        log_info "No activity changes to process"
        exit 0
    fi
    
    local -a changed_files_array
    while IFS= read -r line; do
        [[ -n "$line" ]] && changed_files_array+=("$line") 
    done <<< "$changed_files_input"
    
    local -A processed_activities
    local -a succeeded_activities
    local -a failed_activities
    local -a skipped_files
    local success_count=0
    local error_count=0
    
    # Process each file
    for file_path in "${changed_files_array[@]}"; do
        # Skip empty lines
        [[ -z "$file_path" ]] && continue
        
        # Expected format: activities/{course_id}/{activity_name}/file.ext
        if [[ "$file_path" =~ ^activities/([^/]+)/([^/]+)/(.*) ]]; then
            local course_id="${BASH_REMATCH[1]}"
            local activity_name="${BASH_REMATCH[2]}"
            local filename="${BASH_REMATCH[3]}" 
            
            # Validate that course_id is a number
            if ! [[ "$course_id" =~ ^[0-9]+$ ]]; then
                log_warning "Incorrect course ID: $file_path (course_id: $course_id). It should be a number. Skipping activity: $activity_name."
                skipped_files+=("$file_path (invalid course ID)")
                ((error_count++))
                continue
            fi
            
            local activity_dir="activities/$course_id/$activity_name"
            local activity_key="$course_id:$activity_name"
            
            # Skip if activity already processed
            if [[ -n "${processed_activities[$activity_key]}" ]]; then
                continue 
            fi
            
            # Mark this activity as processed
            processed_activities[$activity_key]=1
            
            log_info "Processing activity: $activity_name in course $course_id (triggered by: $filename)"
            
            # Process the entire activity 
            if process_activity "$course_id" "$activity_dir" ""; then
                succeeded_activities+=("$activity_name (course: $course_id)")
                ((success_count++))
            else
                failed_activities+=("$activity_name (course: $course_id)")
                ((error_count++))
            fi
        else
            log_warning "Skipping file with unexpected path format: $file_path"
            skipped_files+=("$file_path (unexpected path format)")
        fi
    done
    
    echo ""
    echo ""
    echo ""
    log_info "======================================================="
    log_info "FINAL RESULTS"
    log_info "======================================================="
    log_info "Total files processed: ${#changed_files_array[@]}"
    log_info "Activities succeeded: $success_count"
    log_info "Activities failed: $error_count"
    log_info "Files skipped: ${#skipped_files[@]}"
    log_info "======================================================="
 
    
    if [[ ${#succeeded_activities[@]} -gt 0 ]]; then
        log_success "SUCCEEDED ACTIVITIES:"
        for activity in "${succeeded_activities[@]}"; do
            log_success " - $activity"
        done
        echo ""
    fi
    
    if [[ ${#failed_activities[@]} -gt 0 ]]; then
        log_error "FAILED ACTIVITIES:"
        for activity in "${failed_activities[@]}"; do
            log_error " - $activity"
        done
        echo ""
    fi
    
    if [[ ${#skipped_files[@]} -gt 0 ]]; then
        log_warning "SKIPPED FILES:"
        for file in "${skipped_files[@]}"; do
            log_warning " - $file"
        done
        echo ""
    fi
        
    if [[ $error_count -gt 0 ]]; then 
        exit 1
    fi

    exit 0
}

main "$@" 