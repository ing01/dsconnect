import { ref, computed, getCurrentInstance, onBeforeUnmount } from 'vue';
import {
  debounce,
  calculateCenterOffset,
  applyRotationTransform,
  normalizeToPercentage,
} from '@chatwoot/utils';

// Composable for images in gallery view
export const useImageZoom = imageRef => {
  const MAX_ZOOM_LEVEL = 3;
  const MIN_ZOOM_LEVEL = 1;
  const ZOOM_INCREMENT = 0.2;
  const MOUSE_MOVE_DEBOUNCE_MS = 100;
  const MOUSE_LEAVE_DEBOUNCE_MS = 110;
  const DEFAULT_IMG_TRANSFORM_ORIGIN = 'center center';

  const zoomScale = ref(1);
  const imgTransformOriginPoint = ref(DEFAULT_IMG_TRANSFORM_ORIGIN);
  const activeImageRotation = ref(0);
  // Deslocamento (arrasto) da imagem ampliada, no eixo da propria imagem (antes da rotacao).
  const panX = ref(0);
  const panY = ref(0);
  const isPanning = ref(false);
  let panStart = null;

  const resetPan = () => {
    panX.value = 0;
    panY.value = 0;
  };

  function getCursor() {
    if (zoomScale.value > MIN_ZOOM_LEVEL) {
      return isPanning.value ? 'grabbing' : 'grab';
    }
    return 'zoom-in';
  }

  const imageWrapperStyle = computed(() => ({
    transform: `rotate(${activeImageRotation.value}deg)`,
  }));

  const imageStyle = computed(() => ({
    transform: `translate(${panX.value}px, ${panY.value}px) scale(${zoomScale.value})`,
    cursor: getCursor(),
    transformOrigin: `${imgTransformOriginPoint.value}`,
    // Sem transicao enquanto arrasta, senao a imagem fica "pesada" atras do mouse.
    ...(isPanning.value ? { transition: 'none' } : {}),
    ...(zoomScale.value > MIN_ZOOM_LEVEL ? { touchAction: 'none' } : {}),
  }));

  // Resets the transform origin to center
  const resetTransformOrigin = () => {
    if (imageRef.value) {
      imgTransformOriginPoint.value = DEFAULT_IMG_TRANSFORM_ORIGIN;
    }
  };

  // Rotates the current image
  const onRotate = type => {
    if (!imageRef.value) return;
    resetTransformOrigin();

    const rotation = type === 'clockwise' ? 90 : -90;

    // ensure that the value of the rotation is within the range of -360 to 360 degrees
    activeImageRotation.value = (activeImageRotation.value + rotation) % 360;

    // Reset zoom when rotating
    zoomScale.value = 1;
    resetPan();
    resetTransformOrigin();
  };

  /**
   * Calculates the appropriate transform origin point based on mouse position and image rotation
   * Used to create a natural zoom behavior where the image zooms toward/from the cursor position
   *
   * @param {number} x - The client X coordinate of the mouse pointer
   * @param {number} y - The client Y coordinate of the mouse pointer
   * @returns {{x: number, y: number}} Object containing the transform origin coordinates as percentages
   */
  const getZoomOrigin = (x, y) => {
    // Default to center
    if (!imageRef.value) return { x: 50, y: 50 };

    const rect = imageRef.value.getBoundingClientRect();

    // Step 1: Calculate offset from center
    const { relativeX, relativeY } = calculateCenterOffset(x, y, rect);

    // Step 2: Apply rotation transformation
    const { rotatedX, rotatedY } = applyRotationTransform(
      relativeX,
      relativeY,
      activeImageRotation.value
    );

    // Step 3: Convert to percentage coordinates
    return normalizeToPercentage(rotatedX, rotatedY, rect.width, rect.height);
  };

  // Handles zooming the image
  const onZoom = (scale, x, y) => {
    if (!imageRef.value) return;

    // Calculate new scale within bounds
    const newScale = Math.max(
      MIN_ZOOM_LEVEL,
      Math.min(MAX_ZOOM_LEVEL, zoomScale.value + scale)
    );

    // Skip if no change
    if (newScale === zoomScale.value) return;

    // Update transform origin based on mouse position and zoom scale is minimum
    if (x != null && y != null && zoomScale.value === MIN_ZOOM_LEVEL) {
      const { x: originX, y: originY } = getZoomOrigin(x, y);
      imgTransformOriginPoint.value = `${originX}% ${originY}%`;
    }

    // Apply the new scale
    zoomScale.value = newScale;
    if (newScale === MIN_ZOOM_LEVEL) resetPan();
  };

  // Handles double-click zoom toggling
  const onDoubleClickZoomImage = e => {
    if (!imageRef.value) return;
    e.preventDefault();

    // Toggle between max zoom and min zoom
    const newScale =
      zoomScale.value >= MAX_ZOOM_LEVEL ? MIN_ZOOM_LEVEL : MAX_ZOOM_LEVEL;

    // Update transform origin based on mouse position
    const { x: originX, y: originY } = getZoomOrigin(e.clientX, e.clientY);
    imgTransformOriginPoint.value = `${originX}% ${originY}%`;

    // Apply the new scale
    zoomScale.value = newScale;
    if (newScale === MIN_ZOOM_LEVEL) resetPan();
  };

  // Handles mouse wheel zooming for images
  const onWheelImageZoom = e => {
    if (!imageRef.value) return;
    e.preventDefault();

    const scale = e.deltaY > 0 ? -ZOOM_INCREMENT : ZOOM_INCREMENT;
    onZoom(scale, e.clientX, e.clientY);
  };

  /**
   * Sets transform origin to mouse position during hover.
   * Enables precise scroll/double-click zoom targeting by updating the
   * transform origin to cursor position. Only active at minimum zoom level.
   * Debounced (100ms) to improve performance during rapid mouse movement.
   */
  const onMouseMove = debounce(
    e => {
      if (!imageRef.value) return;
      if (zoomScale.value !== MIN_ZOOM_LEVEL) return;

      const { x: originX, y: originY } = getZoomOrigin(e.clientX, e.clientY);
      imgTransformOriginPoint.value = `${originX}% ${originY}%`;
    },
    MOUSE_MOVE_DEBOUNCE_MS,
    false
  );

  /**
   * Resets transform origin to center when mouse leaves image.
   * Ensures button-based zooming works predictably after hover ends.
   * Uses slightly longer debounce (110ms) to avoid conflicts with onMouseMove.
   */
  const onMouseLeave = debounce(
    () => {
      if (!imageRef.value) return;
      if (zoomScale.value !== MIN_ZOOM_LEVEL) return;
      imgTransformOriginPoint.value = DEFAULT_IMG_TRANSFORM_ORIGIN;
    },
    MOUSE_LEAVE_DEBOUNCE_MS,
    false
  );

  // Leva o deslocamento da tela para o eixo da imagem (desfaz a rotacao do quadro).
  const toImageAxis = (dx, dy) => {
    const angle = (-activeImageRotation.value * Math.PI) / 180;
    return {
      x: dx * Math.cos(angle) - dy * Math.sin(angle),
      y: dx * Math.sin(angle) + dy * Math.cos(angle),
    };
  };

  // Nao deixa a imagem sair toda da tela: a borda pode chegar no centro, no maximo.
  const clampPan = (value, size) => {
    const limit = (size * zoomScale.value) / 2;
    return Math.max(-limit, Math.min(limit, value));
  };

  const onPanMove = e => {
    if (!panStart) return;
    const { x, y } = toImageAxis(
      e.clientX - panStart.pointerX,
      e.clientY - panStart.pointerY
    );
    const el = imageRef.value;
    const width = el?.offsetWidth || Infinity;
    const height = el?.offsetHeight || Infinity;
    panX.value = clampPan(panStart.x + x, width);
    panY.value = clampPan(panStart.y + y, height);
  };

  const stopListening = () => {
    window.removeEventListener('pointermove', onPanMove);
    window.removeEventListener('pointerup', onPanEnd);
    window.removeEventListener('pointercancel', onPanEnd);
  };

  function onPanEnd() {
    panStart = null;
    isPanning.value = false;
    stopListening();
  }

  // Comeca a arrastar (so' com a imagem ampliada e botao principal).
  const onPanStart = e => {
    if (!imageRef.value || zoomScale.value <= MIN_ZOOM_LEVEL) return;
    if (e.button != null && e.button !== 0) return;
    e.preventDefault();
    panStart = {
      pointerX: e.clientX,
      pointerY: e.clientY,
      x: panX.value,
      y: panY.value,
    };
    isPanning.value = true;
    window.addEventListener('pointermove', onPanMove);
    window.addEventListener('pointerup', onPanEnd);
    window.addEventListener('pointercancel', onPanEnd);
  };

  if (getCurrentInstance()) onBeforeUnmount(stopListening);

  const resetZoomAndRotation = () => {
    activeImageRotation.value = 0;
    zoomScale.value = 1;
    resetPan();
    onPanEnd();
    resetTransformOrigin();
  };

  return {
    zoomScale,
    imgTransformOriginPoint,
    activeImageRotation,
    panX,
    panY,
    isPanning,
    onPanStart,
    imageWrapperStyle,
    imageStyle,
    getZoomOrigin,
    resetTransformOrigin,
    onRotate,
    onZoom,
    onDoubleClickZoomImage,
    onWheelImageZoom,
    onMouseMove,
    onMouseLeave,
    resetZoomAndRotation,
  };
};
