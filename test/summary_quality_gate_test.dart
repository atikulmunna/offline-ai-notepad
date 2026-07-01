import 'package:flutter_test/flutter_test.dart';
import 'package:offline_ai_notepad/features/ai/data/summary_quality_gate.dart';

void main() {
  const gate = SummaryQualityGate();

  // The note that exposed the bug, used as the body for overlap checks.
  const body =
      'As per the directive of the Management, all employees assigned to the UBL '
      'Project are required to be physically present at the office tomorrow. '
      'Physical office attendance is mandatory for all UBL Project team members. '
      'All employees must report to the office by 11:00 AM. If any employee is '
      'unable to attend due to a genuine emergency, they must inform their '
      'Reporting Manager and submit a clear explanation to Management. Failure to '
      'report without prior approval may be treated as unauthorized absence and '
      'subject to the Company Attendance and Disciplinary Policy.';
  const fallback = 'Extractive fallback summary that differs from the candidate.';

  bool useful(String candidate) =>
      gate.isUseful(candidate, title: 'Office attendance', body: body,
          fallbackSummary: fallback);

  group('rejects on-device failure modes', () {
    test('shouty hallucination with list markers', () {
      expect(
        useful(
          'DISCOVERATION: DISCLAIMER: MEDICAL REQUIREMENTS: (A) ACTION OF '
          'CONSTRUCTION AND CONSTRUTION (B) A list of possible and acceptable '
          'excuses for misconduct or failure to report to the office. (A).',
        ),
        isFalse,
      );
    });

    test('looping bigram repetition', () {
      expect(
        useful(
          'The appointment of a remuneration of a remuneration of a remuneration '
          'of a remuneration of a remuneration is required.',
        ),
        isFalse,
      );
    });

    test('repeated dashed phrase', () {
      expect(
        useful(
          'Physical office attendance if necessary if necessary if necessary if '
          'necessary if necessary if necessary today.',
        ),
        isFalse,
      );
    });

    test('off-topic text sharing only a word or two with the note', () {
      expect(
        useful(
          'The recipe calls for fresh basil, garlic, and olive oil simmered '
          'slowly to report a rich tomato office sauce for dinner.',
        ),
        isFalse,
      );
    });
  });

  group('accepts genuine summaries', () {
    test('concise on-topic abstractive summary', () {
      expect(
        useful(
          'All UBL Project employees must report to the office by 11 AM and '
          'unexplained absence may be treated as unauthorized under policy.',
        ),
        isTrue,
      );
    });

    test('two-sentence summary grounded in the note', () {
      expect(
        useful(
          'Management requires every UBL Project employee at the office '
          'tomorrow. Anyone unable to attend must inform their Reporting '
          'Manager and explain the absence.',
        ),
        isTrue,
      );
    });
  });
}
