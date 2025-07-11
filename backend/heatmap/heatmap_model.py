from datetime import datetime, timedelta
from bson import ObjectId
from backend.database import collections
from fastapi import HTTPException
import logging

# Configure logging
logger = logging.getLogger(__name__)

class HeatmapModel:
    def __init__(self):
        self.collection = collections['HeatMap']
    
    def store_heatmap_data(self, sensor_id, empresa, tipo_producto_principal=0, tipo_producto_medium=0, tipo_producto_far=0):
        """
        Store heat map data from ESP32-CAM devices.
        Checks if a document with the same sensor_id already exists.
        If it exists, it will be updated, otherwise a new one is inserted.
        """
        try:
            # Check if a document with the same sensor_id already exists
            existing_doc = self.collection.find_one({
                "sensor_id": sensor_id,
                "empresa": empresa
            })
            
            # Create document with the new fields
            heatmap_document = {
                "sensor_id": sensor_id,
                "tipo_producto_principal": tipo_producto_principal,
                "tipo_producto_medium": tipo_producto_medium,
                "tipo_producto_far": tipo_producto_far,
                "timestamp": datetime.now(),
                "empresa": empresa
            }
            
            if existing_doc:
                # Replace existing document
                result = self.collection.replace_one(
                    {"_id": existing_doc["_id"]},
                    heatmap_document
                )
                logger.info(f"Replaced existing heatmap record for sensor {sensor_id} and empresa {empresa}")
                return str(existing_doc["_id"])
            else:
                # Insert new document
                result = self.collection.insert_one(heatmap_document)
                logger.info(f"Created new heatmap record for sensor {sensor_id} and empresa {empresa}")
                return str(result.inserted_id)
        except Exception as e:
            logger.error(f"Error storing heatmap data: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Error storing heatmap data: {str(e)}")
    
    def get_heatmap_data(self, empresa, hours=24):
        """
        Get heatmap data for the specified company within the given time period
        """
        try:
            # Calculate timestamp for filtering
            filter_time = datetime.now() - timedelta(hours=hours)
            
            # Query data
            cursor = self.collection.find({
                "empresa": empresa,
                "timestamp": {"$gte": filter_time}
            }).sort("timestamp", -1)
            
            # Convert to list and format
            heatmap_data = []
            for document in cursor:
                document["_id"] = str(document["_id"])
                heatmap_data.append(document)
            
            return heatmap_data
        except Exception as e:
            logger.error(f"Error retrieving heatmap data: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Error retrieving heatmap data: {str(e)}")
    
    def get_aggregated_heatmap_data(self, empresa):
        """
        Get aggregated heat map data by sensor for visualization
        """
        try:
            # Aggregate data by sensor_id
            pipeline = [
                {"$match": {"empresa": empresa}},
                {"$group": {
                    "_id": "$sensor_id",
                    "avgPrincipal": {"$avg": "$tipo_producto_principal"},
                    "avgMedium": {"$avg": "$tipo_producto_medium"},
                    "avgFar": {"$avg": "$tipo_producto_far"},
                    "maxPrincipal": {"$max": "$tipo_producto_principal"},
                    "totalReadings": {"$sum": 1},
                    "lastUpdate": {"$max": "$timestamp"}
                }},
                {"$project": {
                    "sensor_id": "$_id",
                    "avgPrincipal": 1,
                    "maxPrincipal": 1,
                    "avgMedium": 1, 
                    "avgFar": 1,
                    "totalReadings": 1,
                    "lastUpdate": 1,
                    "_id": 0
                }}
            ]
            
            # Execute aggregation
            result = list(self.collection.aggregate(pipeline))
            
            return result
        except Exception as e:
            logger.error(f"Error aggregating heatmap data: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Error aggregating heatmap data: {str(e)}") 