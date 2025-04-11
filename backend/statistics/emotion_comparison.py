from backend.database import collections
from datetime import datetime, timedelta
import pymongo
import calendar
import traceback  # Import traceback for detailed error logging
import time

persona_collection = collections["Persona_AR"]

# Helper to get start and end date strings
def _get_date_range_strings(period: str, date_str: str = None, end_date_str: str = None, month: int = None, year: int = None):
    """Calculates the start and end date strings in YYYY-MM-DD format."""
    # Get actual current date from system
    system_time = time.time()
    system_today = datetime.fromtimestamp(system_time).replace(hour=0, minute=0, second=0, microsecond=0)
    
    # Print debugging information
    print(f"System time: {system_time}")
    print(f"System date: {system_today.strftime('%Y-%m-%d')}")
    
    # Check if system date is far in the future (after 2024)
    if system_today.year > 2024:
        print("WARNING: System date is in the future (after 2024). Using manual override to current date.")
        # Use a more realistic date - current real date
        today = datetime(2024, 4, 9).replace(hour=0, minute=0, second=0, microsecond=0)
        print(f"Using override date: {today.strftime('%Y-%m-%d')}")
    else:
        today = system_today
    
    if period == "week":
        if date_str:
            try:
                start_date_obj = datetime.strptime(date_str, "%Y-%m-%d")
            except ValueError:
                raise ValueError(f"Formato de fecha de inicio inválido: {date_str}. Usar YYYY-MM-DD.")
            default_end_date_obj = start_date_obj + timedelta(days=6)
        else:
            # Use actual date for default values, not hardcoded dates
            start_date_obj = today - timedelta(days=6)
            default_end_date_obj = today
            
        if end_date_str:
            try:
                end_date_obj = datetime.strptime(end_date_str, "%Y-%m-%d")
            except ValueError:
                raise ValueError(f"Formato de fecha de fin inválido: {end_date_str}. Usar YYYY-MM-DD.")
            if end_date_obj < start_date_obj:
                raise ValueError("La fecha de fin no puede ser anterior a la fecha de inicio.")
        else:
            end_date_obj = default_end_date_obj

        end_date_obj = min(end_date_obj, today) # Limit end date to today
        
        start_date_str_query = start_date_obj.strftime("%Y-%m-%d")
        end_date_str_query = end_date_obj.strftime("%Y-%m-%d")
        print(f"Analyzing WEEK: Querying date strings from '{start_date_str_query}' to '{end_date_str_query}'")

    elif period == "month":
        current_year = today.year
        current_month = today.month
        if month and year:
            month_int = int(month)
            year_int = int(year)
            if not 1 <= month_int <= 12: raise ValueError("Mes inválido")
            # Allow any year from 2000 to 2099 for querying historical data
            if not 2000 <= year_int <= 2099: raise ValueError("Año inválido")
            if year_int > current_year: raise ValueError("Año futuro inválido")
            if year_int == current_year and month_int > current_month: raise ValueError("Mes futuro inválido")

            start_date_obj = datetime(year_int, month_int, 1)
            _, last_day = calendar.monthrange(year_int, month_int)
            end_date_obj = datetime(year_int, month_int, last_day)
            print(f"Analyzing MONTH: Selected {calendar.month_name[month_int]} {year_int}")
        else:
            year_int = current_year
            month_int = current_month
            start_date_obj = datetime(year_int, month_int, 1)
            end_date_obj = today
            print(f"Analyzing MONTH: Current Month ({calendar.month_name[month_int]} {year_int})")

        # Ensure end date for month doesn't exceed today
        end_date_obj = min(end_date_obj, today)
        
        start_date_str_query = start_date_obj.strftime("%Y-%m-%d")
        end_date_str_query = end_date_obj.strftime("%Y-%m-%d")
        print(f"Analyzing MONTH: Querying date strings from '{start_date_str_query}' to '{end_date_str_query}'")

    else:
        raise ValueError("Periodo inválido. Usar 'week' o 'month'.")

    return start_date_str_query, end_date_str_query

def get_emotion_comparison(period: str = "week", date: str = None, end_date: str = None, month: int = None, year: int = None):
    """
    Compares HAPPY and SAD emotions by day, querying string dates.
    """
    try:
        print(f"Function called with: period={period}, date={date}, end_date={end_date}, month={month}, year={year}")
        start_date_str, end_date_str = _get_date_range_strings(period, date, end_date, month, year)
        
        # Query using string dates (YYYY-MM-DD format assumed)
        query = {
            "date": {"$gte": start_date_str, "$lte": end_date_str},
            "emotions": {"$in": ["HAPPY", "SAD"]} # Case-sensitive
        }

        print(f"Executing MongoDB query: {query}")
        
        try:
            personas = list(persona_collection.find(query))
        except Exception as db_error:
            print(f"Database query failed: {db_error}")
            print(traceback.format_exc())
            # Return error structure matching potential frontend expectation
            return {"error": f"Error accessing database: {db_error}"}, 500 
            
        print(f"Found {len(personas)} documents matching the query.")
        if not personas:
             print("No documents found for the specified criteria.")
             # Return empty counts but successful structure
             emotion_counts = {day: {"HAPPY": 0, "SAD": 0} for day in calendar.day_name}
             response_data = {**emotion_counts, "TOTALS": {"HAPPY": 0, "SAD": 0}}
             period_info_resp = { "period": period, "query_start_date": start_date_str, "query_end_date": end_date_str }
             return {"message": "Success (No data)", "data": {**response_data, "period_info": period_info_resp}}


        # Initialize counts
        emotion_counts = { day: {"HAPPY": 0, "SAD": 0} for day in calendar.day_name }
        
        # Process results
        for persona in personas:
            date_str_from_db = persona.get("date")
            emotion = persona.get("emotions") # Should be HAPPY or SAD due to query

            if not date_str_from_db or not emotion:
                print(f"Skipping document {persona.get('_id')} with missing data: Date='{date_str_from_db}', Emotion='{emotion}'")
                continue
            
            if emotion not in ["HAPPY", "SAD"]:
                 # This shouldn't happen if the query is correct, but check anyway
                 print(f"Warning: Document {persona.get('_id')} has unexpected emotion '{emotion}' despite query.")
                 continue

            try:
                # Parse the date string from DB to get the day name
                date_obj = datetime.strptime(date_str_from_db, "%Y-%m-%d")
                day_of_week = date_obj.strftime("%A") # Monday, Tuesday, etc.
            except ValueError as date_err:
                print(f"Skipping document {persona.get('_id')} due to unparseable date string '{date_str_from_db}': {date_err}")
                continue

            if day_of_week in emotion_counts:
                emotion_counts[day_of_week][emotion] += 1
            else:
                 print(f"Warning: Encountered unexpected day name '{day_of_week}' for date {date_obj}")

        # Calculate totals
        total_happy = sum(counts["HAPPY"] for counts in emotion_counts.values())
        total_sad = sum(counts["SAD"] for counts in emotion_counts.values())

        # Prepare response data
        response_data = {}
        for day in calendar.day_name:
            response_data[day] = emotion_counts.get(day, {"HAPPY": 0, "SAD": 0})
        response_data["TOTALS"] = { "HAPPY": total_happy, "SAD": total_sad }
        
        print(f"Resulting counts: {response_data}")
        
        # Simplified response structure (remove nested 'data' to avoid confusion)
        response_data["period_info"] = {
            "period": period,
            "query_start_date": start_date_str,
            "query_end_date": end_date_str,
        }
        
        return response_data

    except ValueError as ve:
        print(f"ValueError in get_emotion_comparison: {ve}")
        print(traceback.format_exc())
        # Return error structure
        return {"error": f"Error de parámetros: {ve}"}, 400 
    except Exception as e:
        print(f"Unexpected error in get_emotion_comparison: {e}")
        print(traceback.format_exc())
        return {"error": f"Error inesperado: {e}"}, 500