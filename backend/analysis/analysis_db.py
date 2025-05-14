from fastapi import HTTPException
import logging
from datetime import datetime
import pymongo
from pytz import timezone
from backend.database import collections
from backend.statistics.incremental_stats import update_statistics_on_insert

# Configure logging
logger = logging.getLogger(__name__)

# Define Venezuela timezone
venezuela_tz = timezone('America/Caracas')

def get_next_sequence_value(sequence_name: str) -> int:
    """
    Gets the next value in a sequence from the counters collection.
    
    Args:
        sequence_name: The name of the sequence
    
    Returns:
        int: The next sequence value
        
    Raises:
        HTTPException: If unable to get the next sequence value
    """
    try:
        sequence_document = collections['counters'].find_one_and_update(
            {"_id": sequence_name},
            {"$inc": {"seq": 1}},
            return_document=pymongo.ReturnDocument.AFTER
        )
        
        if sequence_document is None:
            raise Exception("Sequence document not found")
            
        return sequence_document["seq"]
        
    except Exception as e:
        logger.error(f"Error getting next sequence value: {e}")
        raise HTTPException(status_code=500, 
                           detail=f"Error getting next sequence value: {e}")

async def save_analysis_to_db(analysis_results: dict, id_camara: int, empresa: str) -> dict:
    """
    Saves face analysis results to the database and updates statistics.
    
    Args:
        analysis_results: AWS Rekognition analysis results
        id_camara: The camera ID associated with the image
        empresa: The company name
    
    Returns:
        dict: A summary of the processing results
    
    Raises:
        HTTPException: If saving to the database fails
    """
    try:
        logger.info("Starting to save analysis results to database")
        
        # Get product type and category information from camera
        tipo_producto_zona_camara = collections['Tipo_Producto_Zona_Camara'].find_one({"Id_Camara": id_camara})
        if not tipo_producto_zona_camara:
            raise HTTPException(status_code=404, detail="Camera ID not found in Tipo_Producto_Zona_Camara")

        tipo_producto = tipo_producto_zona_camara['Tipo_Producto']
        logger.info(f"Found tipo_producto: {tipo_producto}")

        # Get product category from product type
        tipo_producto_doc = collections['Tipo_Producto'].find_one({"Tipo_Producto": tipo_producto})
        if not tipo_producto_doc:
            raise HTTPException(status_code=404, detail="Tipo_Producto not found in Tipo_Producto")

        categoria_producto = tipo_producto_doc['Categoria_Producto']
        logger.info(f"Found categoria_producto: {categoria_producto}")

        # Get current time in Venezuela timezone
        now_venezuela = datetime.now(venezuela_tz)
        
        # Filter the results to extract face details
        filtered_faces = []
        for face_detail in analysis_results['FaceDetails']:
            filtered_face = {
                'AgeRange': face_detail.get('AgeRange'),
                'Gender': face_detail.get('Gender'),
                'Emotions': face_detail.get('Emotions')
            }
            filtered_faces.append(filtered_face)
        
        # Counters to track processing
        documents_processed = 0
        stats_update_errors = 0
        
        # Process each detected face
        for face in filtered_faces:
            try:
                # Get the primary emotion (highest confidence)
                emotions = face['Emotions']
                primary_emotion = max(emotions, key=lambda x: x['Confidence'])['Type']
                
                # Create document to insert
                document = {
                    "id": get_next_sequence_value("persona_id"),
                    "date": now_venezuela.strftime("%Y-%m-%d"),
                    "time": now_venezuela.strftime("%H:%M:%S"),
                    "id_camara": id_camara,
                    "categoria_producto": categoria_producto,
                    "empresa": empresa,
                    "gender": face['Gender']['Value'],
                    "age_range": {
                        "low": face['AgeRange']['Low'],
                        "high": face['AgeRange']['High']
                    },
                    "emotions": primary_emotion
                }
                
                # Insert into Persona_AR collection
                insert_result = collections['Persona_AR'].insert_one(document)
                
                # Verify insertion and update statistics
                if insert_result.acknowledged:
                    logger.info(f"Document inserted successfully with ID: {document['id']}")
                    
                    # Update statistics incrementally
                    try:
                        logger.info(f"Updating statistics for document ID: {document['id']}")
                        update_statistics_on_insert(document)
                        logger.info(f"Statistics updated successfully for document ID: {document['id']}")
                        documents_processed += 1
                    except Exception as stats_error:
                        logger.error(f"Error updating statistics for document ID {document['id']}: {stats_error}")
                        stats_update_errors += 1
                        # Continue with next document
                else:
                    logger.warning(f"Document insertion not acknowledged for face: {face['Gender']['Value']}")
            except Exception as face_error:
                logger.error(f"Error processing face {face.get('Gender',{}).get('Value', 'unknown')}: {face_error}")
                continue
        
        # Generate response message
        if documents_processed > 0:
            status_msg = f"Processed {documents_processed} documents successfully"
            if stats_update_errors > 0:
                status_msg += f", but there were {stats_update_errors} errors updating statistics"
            
            logger.info(status_msg)
            return {"message": status_msg}
        else:
            error_msg = "Could not process any documents successfully"
            logger.error(error_msg)
            raise HTTPException(status_code=500, detail=error_msg)
            
    except HTTPException:
        # Re-raise HTTP exceptions
        raise
    except Exception as e:
        logger.error(f"Error saving analysis to database: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error saving analysis to database: {str(e)}") 