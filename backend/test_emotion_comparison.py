from backend.statistics.emotion_comparison import get_emotion_comparison

# Test with specific parameters for a valid month (March 2024)
result = get_emotion_comparison(period='month', month=3, year=2024)
print("Result for month=3, year=2024:")
print(result)

# Test with a specific week range
result_week_range = get_emotion_comparison(period='week', date='2024-03-01', end_date='2024-03-07')
print("\nResult for specific week (2024-03-01 to 2024-03-07):")
print(result_week_range)

# Test with current week
result_week = get_emotion_comparison(period='week')
print("\nResult for current week:")
print(result_week) 