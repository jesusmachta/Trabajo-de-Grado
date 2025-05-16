from fastapi import APIRouter, Depends, Body, HTTPException
from typing import Dict, Any, List, Optional
from backend.auth.dependencies import get_empresa, get_current_user
from backend.heatmap.heatmap_model import HeatmapModel
import logging

# Configure logging
logger = logging.getLogger(__name__)

# Create router
router = APIRouter()

@router.post("/heatmap/data", tags=["HeatMap"])
async def upload_heatmap_data(data: Dict[str, Any] = Body(...)):
    """
    Endpoint to receive heat map data from ESP32-CAM devices.
    This endpoint is public as it needs to be accessed by IoT devices.
    """
    try:
        # Validate required fields
        required_fields = ["location_id", "count", "empresa"]
        for field in required_fields:
            if field not in data:
                raise HTTPException(status_code=400, detail=f"Missing required field: {field}")
        
        # Create model instance
        heatmap_model = HeatmapModel()
        
        # Store data
        result_id = heatmap_model.store_heatmap_data(
            location_id=data["location_id"],
            count=data["count"],
            empresa=data["empresa"]
        )
        
        return {"message": "Heat map data received successfully", "id": result_id}
    except HTTPException as e:
        raise e
    except Exception as e:
        logger.error(f"Error processing heat map data: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error processing heat map data: {str(e)}")

@router.get("/heatmap/data", tags=["HeatMap"], response_model=Dict[str, Any])
async def get_heatmap_data(
    hours: Optional[int] = 24, 
    empresa: str = Depends(get_empresa),
    current_user: dict = Depends(get_current_user)
):
    """
    Endpoint to get heat map data for visualization.
    Protected by authentication.
    """
    try:
        # Create model instance
        heatmap_model = HeatmapModel()
        
        # Get data
        heatmap_data = heatmap_model.get_heatmap_data(empresa, hours)
        
        return {"message": "Success", "data": heatmap_data}
    except HTTPException as e:
        raise e
    except Exception as e:
        logger.error(f"Error retrieving heat map data: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error retrieving heat map data: {str(e)}")

@router.get("/heatmap/aggregated", tags=["HeatMap"], response_model=Dict[str, Any])
async def get_aggregated_heatmap_data(
    empresa: str = Depends(get_empresa),
    current_user: dict = Depends(get_current_user)
):
    """
    Endpoint to get aggregated heat map data by location for visualization.
    Protected by authentication.
    """
    try:
        # Create model instance
        heatmap_model = HeatmapModel()
        
        # Get aggregated data
        aggregated_data = heatmap_model.get_aggregated_heatmap_data(empresa)
        
        return {"message": "Success", "data": aggregated_data}
    except HTTPException as e:
        raise e
    except Exception as e:
        logger.error(f"Error retrieving aggregated heat map data: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error retrieving aggregated heat map data: {str(e)}") 