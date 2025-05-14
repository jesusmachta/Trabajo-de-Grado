# This file makes the analysis directory a proper Python package.
# Export main controller function for easy importing
from .analysis_controller import handle_image_upload

__all__ = ['handle_image_upload'] 