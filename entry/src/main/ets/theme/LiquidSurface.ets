import { LiquidContour, LiquidVector } from './LiquidContour';

export class LiquidBox {
  left: number = 0;
  top: number = 0;
  width: number = 0;
  height: number = 0;
}

export class LiquidSurface {
  static body(frame: LiquidVector): LiquidBox {
    const body: LiquidBox = new LiquidBox();
    const progress: number = Math.max(0, Math.min(1, 1 - frame.values[4]));
    const width: number = Math.max(0, frame.values[2]);
    body.width = width * (frame.values[10] > 0 ? 0.58 + 0.42 * progress : 1);
    body.height = Math.max(0, frame.values[3]);
    body.left = frame.values[0] + (width - body.width) / 2;
    body.top = frame.values[1];
    return body;
  }

  static bounds(frame: LiquidVector): LiquidBox {
    const body: LiquidBox = LiquidSurface.body(frame);
    if (frame.values[10] <= 0) { return body; }
    const bounds: LiquidBox = new LiquidBox();
    bounds.left = Math.min(body.left, frame.values[5]);
    bounds.top = Math.min(body.top, frame.values[6]);
    bounds.width = Math.max(body.left + body.width, frame.values[5] + frame.values[7]) - bounds.left;
    bounds.height = Math.max(body.top + body.height, frame.values[6] + frame.values[8]) - bounds.top;
    return bounds;
  }

  private static neckStrength(progress: number): number {
    const release: number = Math.max(0, Math.min(1, (progress - 0.64) / 0.32));
    return 1 - release * release * (3 - 2 * release);
  }

  static path(frame: LiquidVector, outline: boolean = false): string {
    const body: LiquidBox = LiquidSurface.body(frame);
    if (body.width <= 0 || body.height <= 0) { return 'M 0 0'; }
    const bounds: LiquidBox = LiquidSurface.bounds(frame);
    const density: number = frame.values[9];
    const roundness: number = Math.max(0, Math.min(1, frame.values[4]));
    const strength: number = frame.values[10] > 0 ? LiquidSurface.neckStrength(1 - roundness) : 0;
    const sourceRadius: number = Math.min(frame.values[7], frame.values[8]) / 2;
    const centerX: number = frame.values[5] + frame.values[7] / 2;
    const centerY: number = frame.values[6] + frame.values[8] / 2;
    const direction: number = body.top + body.height / 2 >= centerY ? 1 : -1;
    const nearY: number = direction > 0 ? body.top : body.top + body.height;
    const sourceHalf: number = Math.min(sourceRadius * 0.78, body.width * 0.35) * Math.sqrt(strength);
    const sourceArc: number = Math.sqrt(Math.max(0, sourceRadius * sourceRadius - sourceHalf * sourceHalf));
    const sourceY: number = centerY + direction * sourceArc;
    const corner: number = Math.min(28, body.width / 2, body.height / 2);
    const radiusX: number = body.width / 2 * roundness + corner * (1 - roundness);
    const radiusY: number = body.height / 2 * roundness + corner * (1 - roundness);
    const endHalf: number = Math.min(body.width * 0.24, sourceRadius * 1.4) * Math.sqrt(strength);
    const margin: number = Math.min(body.width / 2, endHalf + radiusX * 0.4);
    const endCenter: number = Math.max(margin, Math.min(body.width - margin, centerX - body.left));
    const leftX: number = endCenter - endHalf;
    const rightX: number = endCenter + endHalf;
    const edgeInset: (position: number) => number = (position: number): number => {
      const offset: number = Math.max(0, radiusX - Math.min(position, body.width - position));
      return radiusY * (1 - Math.sqrt(Math.max(0, 1 - offset * offset / (radiusX * radiusX))));
    };
    const edgeSlope: (position: number) => number = (position: number): number => {
      const offset: number = position < radiusX ? position - radiusX :
        (position > body.width - radiusX ? position - body.width + radiusX : 0);
      const arc: number = Math.sqrt(Math.max(0.0001, radiusX * radiusX - offset * offset));
      return radiusY * offset / (radiusX * arc);
    };
    const distance: number = direction * (nearY - sourceY);
    const point: (pointX: number, pointY: number) => string = (pointX: number, pointY: number): string =>
      `${(body.left - bounds.left + pointX) * density} ${(nearY - bounds.top + direction * pointY) * density}`;
    const absolute: (pointX: number, pointY: number) => string = (pointX: number, pointY: number): string =>
      `${(pointX - bounds.left) * density} ${(pointY - bounds.top) * density}`;
    const arc: (pointX: number, pointY: number) => string = (pointX: number, pointY: number): string =>
      `A ${radiusX * density} ${radiusY * density} 0 0 ${direction > 0 ? 1 : 0} ${point(pointX, pointY)} `;
    if (strength < 0.001 || sourceRadius <= 0 || distance <= 0) {
      return `M ${point(radiusX, 0)} L ${point(body.width - radiusX, 0)} ` + arc(body.width, radiusY) +
        `L ${point(body.width, body.height - radiusY)} ` + arc(body.width - radiusX, body.height) +
        `L ${point(radiusX, body.height)} ` + arc(0, body.height - radiusY) +
        `L ${point(0, radiusY)} ` + arc(radiusX, 0) + 'Z';
    }
    const leftY: number = edgeInset(leftX);
    const rightY: number = edgeInset(rightX);
    const waistX: number = centerX + (body.left + endCenter - centerX) * 0.5;
    const waistY: number = sourceY + direction * (distance + (leftY + rightY) / 2) * 0.5;
    const waistHalf: number = Math.min(sourceHalf, endHalf) * (0.6 + 0.2 * strength);
    const reach: number = Math.min(sourceRadius * 0.85, (distance + Math.max(leftY, rightY)) * 0.6);
    const rightSlope: number = edgeSlope(rightX);
    const leftSlope: number = edgeSlope(leftX);
    const rightReach: number = reach / Math.sqrt(1 + rightSlope * rightSlope);
    const leftReach: number = reach / Math.sqrt(1 + leftSlope * leftSlope);
    const sourceReachX: number = reach * sourceArc / sourceRadius;
    const sourceReachY: number = reach * sourceHalf / sourceRadius;
    let path: string = `M ${absolute(centerX + sourceHalf, sourceY)} ` +
      `C ${absolute(centerX + sourceHalf - sourceReachX, sourceY + direction * sourceReachY)} ` +
      `${absolute(waistX + waistHalf, waistY - direction * reach * 0.35)} ${absolute(waistX + waistHalf, waistY)} ` +
      `C ${absolute(waistX + waistHalf, waistY + direction * reach * 0.35)} ` +
      `${point(rightX - rightReach, rightY - rightReach * rightSlope)} ${point(rightX, rightY)} `;
    if (rightX < radiusX) { path += arc(radiusX, 0); }
    if (rightX < body.width - radiusX) { path += `L ${point(body.width - radiusX, 0)} `; }
    path += arc(body.width, radiusY) + `L ${point(body.width, body.height - radiusY)} ` +
      arc(body.width - radiusX, body.height) + `L ${point(radiusX, body.height)} ` +
      arc(0, body.height - radiusY) + `L ${point(0, radiusY)} `;
    if (leftX <= radiusX) {
      path += arc(leftX, leftY);
    } else {
      path += arc(radiusX, 0);
      if (leftX <= body.width - radiusX) { path += `L ${point(leftX, 0)} `; }
      else { path += `L ${point(body.width - radiusX, 0)} ` + arc(leftX, leftY); }
    }
    path += `C ${point(leftX + leftReach, leftY + leftReach * leftSlope)} ` +
      `${absolute(waistX - waistHalf, waistY + direction * reach * 0.35)} ${absolute(waistX - waistHalf, waistY)} ` +
      `C ${absolute(waistX - waistHalf, waistY - direction * reach * 0.35)} ` +
      `${absolute(centerX - sourceHalf + sourceReachX, sourceY + direction * sourceReachY)} ` +
      `${absolute(centerX - sourceHalf, sourceY)} `;
    return path + (outline ? '' : 'Z');
  }

  static bodyPath(frame: LiquidVector): string {
    const body: LiquidBox = LiquidSurface.body(frame);
    return LiquidContour.body(body.width, body.height, frame.values[4], frame.values[9]);
  }
}
