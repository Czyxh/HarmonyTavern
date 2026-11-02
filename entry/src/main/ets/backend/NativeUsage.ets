import { Backend } from './Backend';
export interface UsageDay { date: string; count: number; }
export interface UsageRank { name: string; value: number; }
export interface UsageStatistics {
  range: string; from?: string; to: string; updated_at: string; heat: UsageDay[];
  heat_active_days: number; heat_longest_streak: number;
  conversations: number; messages: number; models: number; active_days: number; longest_streak: number;
  model_rank: UsageRank[]; token_rank: UsageRank[]; sources: UsageRank[]; requests: number;
  input?: number; output?: number; total?: number; cached?: number; cache_rate?: number; average?: number;
  known_usage: number; missing_usage: number; partial_usage: number; average_samples: number;
  unknown_dates: number; unknown_models: number; invalid_rows: number;
}
export class NativeUsage {
  static get(range: string): Promise<UsageStatistics> {
    return Backend.call<UsageStatistics>('get_native_usage_statistics', {
      range: range, offsetMinutes: -new Date().getTimezoneOffset()
    });
  }
}
