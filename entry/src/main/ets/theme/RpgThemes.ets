import { ColorTokens } from './Tokens';
import { CustomPalette } from './CustomPalette';

export interface RpgPalette {
  background: string;
  surface: string;
  surfaceHigh: string;
  accent: string;
  ornament: string;
}

export interface RpgThemeDefinition {
  id: string;
  label: string;
  description: string;
  radius: number;
  borderWidth: number;
  light: RpgPalette;
  dark: RpgPalette;
}

export const RPG_THEMES: RpgThemeDefinition[] = [
  {
    id: 'rpg_journal', label: '冒险者手札', description: '羊皮纸、古铜与墨绿，写下酒馆里的新故事',
    radius: 12, borderWidth: 1,
    light: { background: '#E9DFC7', surface: '#F5EDD9', surfaceHigh: '#E0D2B1',
      accent: '#49633B', ornament: '#98703B' },
    dark: { background: '#25271F', surface: '#303329', surfaceHigh: '#3C3F32',
      accent: '#C4CF99', ornament: '#D8B97C' }
  },
  {
    id: 'rpg_sakura', label: '绯樱物语', description: '和纸、朱印与靛青，一卷安静的旅途物语',
    radius: 6, borderWidth: 0.8,
    light: { background: '#F1E9DC', surface: '#FCF6EB', surfaceHigh: '#E5D9C9',
      accent: '#943C42', ornament: '#A47E54' },
    dark: { background: '#222330', surface: '#2D2E3C', surfaceHigh: '#3C3B4A',
      accent: '#F1ADB2', ornament: '#D6BD97' }
  },
  {
    id: 'rpg_pixel', label: '像素旅人', description: '像素城镇、方格边框，重温掌机里的冒险',
    radius: 2, borderWidth: 2,
    light: { background: '#DDE6C9', surface: '#F2F3DD', surfaceHigh: '#CDD9B5',
      accent: '#3B573D', ornament: '#857041' },
    dark: { background: '#192923', surface: '#23372C', surfaceHigh: '#304938',
      accent: '#C6DEA0', ornament: '#E0C58B' }
  },
  {
    id: 'rpg_dungeon', label: '烬火地牢', description: '风化石壁、锻铁与余烬，向未知的深处前行',
    radius: 4, borderWidth: 1.2,
    light: { background: '#DDD7CE', surface: '#EEE8DF', surfaceHigh: '#CFC5B7',
      accent: '#803E32', ornament: '#806840' },
    dark: { background: '#1F2023', surface: '#2A2B2E', surfaceHigh: '#38383A',
      accent: '#E5B279', ornament: '#C89B63' }
  }
];

export class RpgThemes {
  static find(id: string): RpgThemeDefinition | undefined {
    return RPG_THEMES.find((theme: RpgThemeDefinition): boolean => theme.id === id);
  }

  static active(): RpgThemeDefinition | undefined {
    return RpgThemes.find(AppStorage.get<string>('appearanceBackground') ?? 'paper');
  }

  static palette(id: string): RpgPalette {
    const theme: RpgThemeDefinition = RpgThemes.find(id) ?? RPG_THEMES[0];
    return (AppStorage.get<boolean>('appearanceIsDark') ?? false) ? theme.dark : theme.light;
  }

  static colors(id: string): ColorTokens {
    const palette: RpgPalette = RpgThemes.palette(id);
    const colors: ColorTokens = CustomPalette.colors(palette.background, palette.accent);
    const surfaces: string[] = [palette.background, palette.surface, palette.surfaceHigh];
    colors.bgSurface = palette.surface;
    colors.bgSurfaceHigh = palette.surfaceHigh;
    colors.accentContainer = CustomPalette.mix(palette.surface, palette.accent, 0.09);
    surfaces.push(colors.accentContainer as string);
    colors.textPrimary = CustomPalette.readable(colors.textPrimary as string, surfaces, 7);
    colors.textSecondary = CustomPalette.readable(colors.textSecondary as string, surfaces);
    colors.textTertiary = CustomPalette.readable(colors.textTertiary as string, surfaces);
    colors.accent = CustomPalette.readable(palette.accent, surfaces);
    colors.textInverse = CustomPalette.readable('#FFFFFF', [colors.accent as string]);
    colors.accentPressed = CustomPalette.mix(colors.accent as string, colors.textInverse === '#FFFFFF' ? '#000000' : '#FFFFFF', 0.12);
    colors.borderSubtle = CustomPalette.mix(palette.surface, palette.ornament, 0.48);
    colors.borderStrong = CustomPalette.mix(palette.surface, palette.ornament, 0.82);
    colors.danger = CustomPalette.readable(colors.danger as string, surfaces);
    colors.success = CustomPalette.readable(colors.success as string, surfaces);
    colors.warning = CustomPalette.readable(colors.warning as string, surfaces);
    colors.glassTint = CustomPalette.alpha(palette.surface, 'B3');
    colors.glassEdge = CustomPalette.alpha(palette.ornament, '38');
    colors.headerButtonTint = CustomPalette.alpha(palette.surface, 'A6');
    colors.dockTint = CustomPalette.alpha(palette.surface, '66');
    colors.lensTint = CustomPalette.alpha(palette.surfaceHigh, '80');
    colors.reflection = CustomPalette.alpha(palette.ornament, '24');
    return colors;
  }

  static radius(fallback: number): number {
    return RpgThemes.active()?.radius ?? fallback;
  }

  static borderWidth(fallback: number): number {
    return RpgThemes.active()?.borderWidth ?? fallback;
  }

  static art(id: string): Resource {
    if (id === 'rpg_journal') { return $r('app.media.rpg_journal'); }
    if (id === 'rpg_sakura') { return $r('app.media.rpg_sakura'); }
    if (id === 'rpg_pixel') { return $r('app.media.rpg_pixel'); }
    if (id === 'rpg_dungeon') { return $r('app.media.rpg_dungeon'); }
    return $r('app.media.rpg_journal');
  }

  static texture(id: string): Resource {
    if (id === 'rpg_journal') { return $r('app.media.rpg_journal_texture'); }
    if (id === 'rpg_sakura') { return $r('app.media.rpg_sakura_texture'); }
    if (id === 'rpg_pixel') { return $r('app.media.rpg_pixel_texture'); }
    if (id === 'rpg_dungeon') { return $r('app.media.rpg_dungeon_texture'); }
    return $r('app.media.rpg_journal_texture');
  }

  static frame(id: string): Resource {
    if (id === 'rpg_journal') { return $r('app.media.rpg_journal_frame'); }
    if (id === 'rpg_sakura') { return $r('app.media.rpg_sakura_frame'); }
    if (id === 'rpg_pixel') { return $r('app.media.rpg_pixel_frame'); }
    if (id === 'rpg_dungeon') { return $r('app.media.rpg_dungeon_frame'); }
    return $r('app.media.rpg_journal_frame');
  }
}
