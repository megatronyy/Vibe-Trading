import 'dart:math';

/// Direct port of `frontend/src/lib/indicators.ts` — pure technical-indicator
/// math with zero chart-library dependency. Used by the candlestick overlay /
/// sub-chart rendering. `null` entries mark the warm-up period (matching TS).

List<double?> calcMA(List<double> data, int period) {
  return List<double?>.generate(data.length, (i) {
    if (i < period - 1) return null;
    double s = 0;
    for (int j = i - period + 1; j <= i; j++) {
      s += data[j];
    }
    return s / period;
  });
}

List<double?> calcEMA(List<double> data, int period) {
  final k = 2 / (period + 1);
  final out = <double?>[];
  double? ema;
  for (int i = 0; i < data.length; i++) {
    if (i < period - 1) {
      out.add(null);
    } else if (ema == null) {
      double s = 0;
      for (int j = 0; j < period; j++) {
        s += data[j];
      }
      ema = s / period;
      out.add(ema);
    } else {
      ema = data[i] * k + ema * (1 - k);
      out.add(ema);
    }
  }
  return out;
}

class BollResult {
  const BollResult(this.upper, this.mid, this.lower);
  final List<double?> upper;
  final List<double?> mid;
  final List<double?> lower;
}

BollResult calcBOLL(List<double> data, int period, [double mult = 2]) {
  final mid = calcMA(data, period);
  final upper = <double?>[];
  final lower = <double?>[];
  for (int i = 0; i < data.length; i++) {
    if (mid[i] == null) {
      upper.add(null);
      lower.add(null);
      continue;
    }
    double sq = 0;
    for (int j = i - period + 1; j <= i; j++) {
      sq += pow(data[j] - mid[i]!, 2);
    }
    final std = sqrt(sq / period);
    upper.add(mid[i]! + mult * std);
    lower.add(mid[i]! - mult * std);
  }
  return BollResult(upper, mid, lower);
}

class MacdResult {
  const MacdResult(this.dif, this.signal, this.histogram);
  final List<double?> dif;
  final List<double?> signal;
  final List<double?> histogram;
}

MacdResult calcMACD(List<double> data,
    [int fast = 12, int slow = 26, int sig = 9]) {
  final ef = calcEMA(data, fast);
  final es = calcEMA(data, slow);
  final dif = List<double?>.generate(
      data.length, (i) => (ef[i] != null && es[i] != null) ? ef[i]! - es[i]! : null);

  // Signal = EMA of the non-null DIF values, mapped back to original indices.
  final valid = <double>[];
  final idx = <int>[];
  for (int i = 0; i < dif.length; i++) {
    if (dif[i] != null) {
      valid.add(dif[i]!);
      idx.add(i);
    }
  }
  final sigEma = calcEMA(valid, sig);
  final signal = List<double?>.filled(data.length, null);
  final hist = List<double?>.filled(data.length, null);
  for (int j = 0; j < idx.length; j++) {
    if (sigEma[j] != null) {
      signal[idx[j]] = sigEma[j];
      hist[idx[j]] = dif[idx[j]]! - sigEma[j]!;
    }
  }
  return MacdResult(dif, signal, hist);
}

List<double?> calcRSI(List<double> data, [int period = 14]) {
  if (data.length < period + 1) {
    return List<double?>.filled(data.length, null);
  }
  final out = List<double?>.filled(data.length, null);
  double avgG = 0, avgL = 0;
  for (int i = 1; i <= period; i++) {
    final c = data[i] - data[i - 1];
    if (c > 0) {
      avgG += c;
    } else {
      avgL -= c;
    }
  }
  avgG /= period;
  avgL /= period;
  out[period] = avgL == 0 ? 100 : 100 - 100 / (1 + avgG / avgL);
  for (int i = period + 1; i < data.length; i++) {
    final c = data[i] - data[i - 1];
    avgG = (avgG * (period - 1) + (c > 0 ? c : 0)) / period;
    avgL = (avgL * (period - 1) + (c < 0 ? -c : 0)) / period;
    out[i] = avgL == 0 ? 100 : 100 - 100 / (1 + avgG / avgL);
  }
  return out;
}

class KdjResult {
  const KdjResult(this.k, this.d, this.j);
  final List<double?> k;
  final List<double?> d;
  final List<double?> j;
}

KdjResult calcKDJ(List<double> highs, List<double> lows, List<double> closes,
    [int period = 9]) {
  final n = closes.length;
  final k = List<double?>.filled(n, null);
  final d = List<double?>.filled(n, null);
  final j = List<double?>.filled(n, null);
  if (n < period) return KdjResult(k, d, j);
  double pk = 50, pd = 50;
  for (int i = period - 1; i < n; i++) {
    double hi = -1e18, lo = 1e18;
    for (int p = i - period + 1; p <= i; p++) {
      if (highs[p] > hi) hi = highs[p];
      if (lows[p] < lo) lo = lows[p];
    }
    final rsv = hi == lo ? 50 : ((closes[i] - lo) / (hi - lo)) * 100;
    pk = (pk * 2 + rsv) / 3;
    pd = (pd * 2 + pk) / 3;
    k[i] = pk;
    d[i] = pd;
    j[i] = 3 * pk - 2 * pd;
  }
  return KdjResult(k, d, j);
}
