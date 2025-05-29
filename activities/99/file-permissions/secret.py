# Secret file - hidden from students
# This file contains the solution and is not visible to students

from helper import get_data


def secret_solution():
    """
    This is the complete solution that students should not see.
    It's used for grading purposes.
    """
    data = get_data()
    return [x * 2 for x in data]


def grading_function(student_result):
    """
    Used by the grading system to evaluate student submissions.
    """
    expected = secret_solution()
    return student_result == expected
