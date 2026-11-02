export class LiquidVector implements AnimatableArithmetic<LiquidVector> {
  values: number[];

  constructor(values: number[]) { this.values = values; }

  plus(rhs: LiquidVector): LiquidVector {
    return new LiquidVector(this.values.map((value: number, index: number): number => value + rhs.values[index]));
  }

  subtract(rhs: LiquidVector): LiquidVector {
    return new LiquidVector(this.values.map((value: number, index: number): number => value - rhs.values[index]));
  }

  multiply(scale: number): LiquidVector {
    return new LiquidVector(this.values.map((value: number): number => value * scale));
  }

  equals(rhs: LiquidVector): boolean {
    return this.values.length === rhs.values.length &&
      this.values.every((value: number, index: number): boolean => Math.abs(value - rhs.values[index]) < 0.0001);
  }
}

export class LiquidContour {
  static body(width: number, height: number, roundness: number, density: number): string {
    if (width <= 0 || height <= 0) { return 'M 0 0'; }
    const progress: number = Math.max(0, Math.min(1, roundness));
    const corner: number = Math.min(28, width / 2, height / 2);
    const radiusX: number = (width / 2 * progress + corner * (1 - progress)) * density;
    const radiusY: number = (height / 2 * progress + corner * (1 - progress)) * density;
    const right: number = width * density;
    const bottom: number = height * density;
    const controlX: number = radiusX * 0.5522847498;
    const controlY: number = radiusY * 0.5522847498;
    return `M ${radiusX} 0 H ${right - radiusX} ` +
      `C ${right - radiusX + controlX} 0 ${right} ${radiusY - controlY} ${right} ${radiusY} ` +
      `V ${bottom - radiusY} C ${right} ${bottom - radiusY + controlY} ` +
      `${right - radiusX + controlX} ${bottom} ${right - radiusX} ${bottom} ` +
      `H ${radiusX} C ${radiusX - controlX} ${bottom} 0 ${bottom - radiusY + controlY} 0 ${bottom - radiusY} ` +
      `V ${radiusY} C 0 ${radiusY - controlY} ${radiusX - controlX} 0 ${radiusX} 0 Z`;
  }

  static radius(width: number, height: number, roundness: number): number {
    const progress: number = Math.max(0, Math.min(1, roundness));
    return Math.min(width, height) / 2 * progress + Math.min(28, Math.min(width, height) / 2) * (1 - progress);
  }

  static bridge(sourceLeft: number, sourceTop: number, sourceWidth: number, sourceHeight: number,
    panelLeft: number, panelTop: number, panelWidth: number, panelHeight: number,
    strength: number, density: number, outline: boolean = false, roundness: number = 0): string {
    const tension: number = Math.max(0, Math.min(1, strength));
    const radius: number = Math.min(sourceWidth, sourceHeight) / 2;
    const centerX: number = sourceLeft + sourceWidth / 2;
    const centerY: number = sourceTop + sourceHeight / 2;
    const direction: number = panelTop + panelHeight / 2 >= centerY ? 1 : -1;
    const startY: number = centerY + direction * radius * 0.62;
    const endY: number = direction > 0 ? panelTop : panelTop + panelHeight;
    const distance: number = direction * (endY - startY);
    if (tension < 0.001 || distance <= 0 || panelWidth <= 0 || panelHeight <= 0 || radius <= 0) { return 'M 0 0'; }
    const startHalf: number = radius * 0.78 * Math.sqrt(tension);
    const endHalf: number = Math.min(panelWidth * 0.24, radius * 1.4) * Math.sqrt(tension);
    const progress: number = Math.max(0, Math.min(1, roundness));
    const corner: number = Math.min(28, panelWidth / 2, panelHeight / 2);
    const cornerX: number = panelWidth / 2 * progress + corner * (1 - progress);
    const cornerY: number = panelHeight / 2 * progress + corner * (1 - progress);
    const margin: number = Math.min(panelWidth / 2, endHalf + cornerX * 0.4);
    const endX: number = Math.max(panelLeft + margin, Math.min(panelLeft + panelWidth - margin, centerX));
    const leftX: number = endX - endHalf;
    const rightX: number = endX + endHalf;
    const leftInset: number = Math.max(0, cornerX - Math.min(leftX - panelLeft, panelLeft + panelWidth - leftX));
    const rightInset: number = Math.max(0, cornerX - Math.min(rightX - panelLeft, panelLeft + panelWidth - rightX));
    const leftArc: number = Math.sqrt(Math.max(0, cornerX * cornerX - leftInset * leftInset));
    const rightArc: number = Math.sqrt(Math.max(0, cornerX * cornerX - rightInset * rightInset));
    const leftY: number = endY + direction * (cornerY * (1 - leftArc / cornerX) + 1);
    const rightY: number = endY + direction * (cornerY * (1 - rightArc / cornerX) + 1);
    const reach: number = Math.min(distance * 0.55, radius * 0.8);
    const leftSlope: number = cornerY * leftInset / cornerX;
    const rightSlope: number = cornerY * rightInset / cornerX;
    const leftLength: number = Math.max(0.001, Math.sqrt(leftArc * leftArc + leftSlope * leftSlope));
    const rightLength: number = Math.max(0.001, Math.sqrt(rightArc * rightArc + rightSlope * rightSlope));
    const leftReachX: number = reach * leftArc / leftLength;
    const leftReachY: number = reach * leftSlope / leftLength;
    const rightReachX: number = reach * rightArc / rightLength;
    const rightReachY: number = reach * rightSlope / rightLength;
    const waistHalf: number = Math.max(0.1, radius * 0.23 * tension);
    const waistX: number = centerX + (endX - centerX) * 0.45;
    const waistY: number = startY + direction * distance * 0.48;
    const left: string = `M ${(centerX - startHalf) * density} ${startY * density} ` +
      `C ${(centerX - startHalf + reach * 0.62) * density} ${(startY + direction * reach * 0.78) * density} ` +
      `${(waistX - waistHalf) * density} ${(waistY - direction * distance * 0.2) * density} ` +
      `${(waistX - waistHalf) * density} ${waistY * density} ` +
      `C ${(waistX - waistHalf) * density} ${(waistY + direction * distance * 0.2) * density} ` +
      `${(leftX + leftReachX) * density} ${(leftY - direction * leftReachY) * density} ` +
      `${leftX * density} ${leftY * density} `;
    const right: string = `${outline ? 'M' : 'L'} ${rightX * density} ${rightY * density} ` +
      `C ${(rightX - rightReachX) * density} ${(rightY - direction * rightReachY) * density} ` +
      `${(waistX + waistHalf) * density} ${(waistY + direction * distance * 0.2) * density} ` +
      `${(waistX + waistHalf) * density} ${waistY * density} ` +
      `C ${(waistX + waistHalf) * density} ${(waistY - direction * distance * 0.2) * density} ` +
      `${(centerX + startHalf - reach * 0.62) * density} ${(startY + direction * reach * 0.78) * density} ` +
      `${(centerX + startHalf) * density} ${startY * density} ${outline ? '' : 'Z'}`;
    return left + right;
  }
}
