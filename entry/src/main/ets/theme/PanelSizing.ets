export class PanelSizing {
  header: number = 0;
  body: number = 0;
  footer: number = 0;

  update(section: 'header' | 'body' | 'footer', height: number): void {
    if (!Number.isFinite(height) || height < 0) { return; }
    const measured: number = Math.ceil(height);
    if (section === 'header' && Math.abs(this.header - measured) > 0.5) { this.header = measured; }
    if (section === 'body' && Math.abs(this.body - measured) > 0.5) { this.body = measured; }
    if (section === 'footer' && Math.abs(this.footer - measured) > 0.5) { this.footer = measured; }
  }

  limit(maximum: number): number {
    const available: number = Number.isFinite(maximum) ? Math.max(1, maximum) : 1;
    if (this.header <= 0 || this.body <= 0) { return available; }
    return Math.max(1, Math.min(available, this.header + this.body + this.footer));
  }
}
