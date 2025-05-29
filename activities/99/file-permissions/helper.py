# Helper file - students can read but not modify
def get_data():
    """
    This function provides data for the exercise.
    Students can see this code but cannot modify it.
    """
    return [1, 2, 3, 4, 5]


def validate_result(result):
    """
    Validates the student's result.
    Students can see this for reference.
    """
    return isinstance(result, list) and len(result) > 0
