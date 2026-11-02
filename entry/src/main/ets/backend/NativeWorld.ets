import { Backend } from './Backend';
import { GenerateRequestDto } from './Types';

export interface WorldMeter {
  label: string;
  value?: number;
  max?: number;
  unit: string;
  kind: string;
  estimated?: boolean;
}
export interface WorldCondition {
  name: string;
  kind: string;
  detail: string;
}
export interface WorldItem {
  name: string;
  quantity?: number;
  detail: string;
  equipment?: boolean;
  equipped?: boolean;
  slot?: string;
}
export interface WorldLocation {
  region: string;
  place: string;
  detail: string;
}
export interface WorldQuest {
  name: string;
  status: string;
  detail: string;
}
export interface WorldRelationship {
  name: string;
  value?: number;
  max?: number;
  detail: string;
}
export interface WorldState {
  version: number;
  title: string;
  subject: string;
  layout: string;
  location: WorldLocation;
  meters: WorldMeter[];
  conditions: WorldCondition[];
  inventory: WorldItem[];
  quests?: WorldQuest[];
  relationships?: WorldRelationship[];
  note: string;
}
export interface WorldStateReport {
  status: string;
  message: string;
  state?: WorldState;
  updated_after?: number;
}
export function worldNeedsInitialization(report: WorldStateReport): boolean {
  return report.state === undefined && (report.status === 'missing' || report.status === 'stale');
}
export interface WorldStatePlan {
  expectedTurn: string;
  dto: GenerateRequestDto;
}
export interface WorldReplyPlan {
  expectedConfig: string;
  dto: GenerateRequestDto;
}
export class NativeWorld {
  static itemAction(characterName: string, fileName: string, expectedState: WorldState, index: number, action: string): Promise<WorldStateReport> {
    return Backend.call<WorldStateReport>('apply_native_world_item_action', {
      characterName: characterName, fileName: fileName, expectedState: expectedState, index: index, action: action
    });
  }
  static prepareReply(characterName: string, fileName: string, dto: GenerateRequestDto, pendingMessage: string): Promise<WorldReplyPlan> {
    return Backend.call<WorldReplyPlan>('prepare_native_world_reply', {
      characterName: characterName, fileName: fileName, dto: dto, pendingMessage: pendingMessage
    });
  }
  static status(characterName: string, fileName: string): Promise<WorldStateReport> {
    return Backend.call<WorldStateReport>('get_native_world_state', { characterName: characterName, fileName: fileName });
  }
  static prepare(characterName: string, fileName: string, dto: GenerateRequestDto, incremental: boolean = false): Promise<WorldStatePlan> {
    return Backend.call<WorldStatePlan>('prepare_native_world_state', {
      characterName: characterName, fileName: fileName, dto: dto, incremental: incremental
    });
  }
  static commit(characterName: string, fileName: string, expectedTurn: string, response: Object): Promise<WorldStateReport> {
    return Backend.call<WorldStateReport>('commit_native_world_state', {
      characterName: characterName, fileName: fileName, expectedTurn: expectedTurn, response: response
    });
  }
}
export function worldLocationLabel(location: WorldLocation): string {
  return [location.region, location.place].filter((value: string): boolean => value.trim() !== '').join(' · ') || '位置未确认';
}
export function worldMeterLabel(meter: WorldMeter): string {
  if (meter.value === undefined || meter.value === null) { return '未确认'; }
  if (meter.estimated === true) { return '约 ' + Math.round(meter.value) + (meter.max === 100 ? '%' : ' / ' + meter.max) + ' · 估算'; }
  return String(meter.value) + (meter.max === undefined || meter.max === null ? '' : ' / ' + meter.max) +
    (meter.unit === '' ? '' : ' ' + meter.unit);
}
export function worldMeterPercent(meter: WorldMeter): number {
  if (meter.value === undefined || meter.value === null || meter.max === undefined || meter.max === null || meter.max <= 0) { return 0; }
  return Math.max(0, Math.min(100, meter.value / meter.max * 100));
}
