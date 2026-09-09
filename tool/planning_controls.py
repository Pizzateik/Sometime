from pathlib import Path
root = Path(__file__).resolve().parent.parent
p = root / 'lib/widgets/task_planning_fields.dart'
s = p.read_text()
start = s.index('  @override\n  Widget build(BuildContext context) => Container(', s.index('class _Pill'))
end = s.index('\nclass _WeekdayPicker', start)
s = s[:start] + '''  @override
  Widget build(BuildContext context) => Pressable(
    label: label,
    onPressed: onPressed,
    excludeChildSemantics: false,
    radius: AppSpace.controlRadius,
    scale: 0.975,
    builder: (context, state) => AnimatedContainer(
      duration: AppMotion.duration(context, AppMotion.press),
      width: compact ? null : double.infinity,
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: active ? context.appColors.strongSelection : context.appColors.pill,
        borderRadius: BorderRadius.circular(AppSpace.controlRadius),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: onClear == null ? 14 : 36, vertical: 14),
          child: Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: active ? context.appColors.onStrongSelection : context.appColors.text)),
        ),
        if (onClear != null) Positioned(right: 0, top: 0, bottom: 0, child: Pressable(
          label: '${context.strings.delete} $label',
          onPressed: onClear,
          builder: (context, state) => SizedBox(width: 36, child: Icon(SometimeIcons.x, size: 15, color: active ? context.appColors.onStrongSelection : context.appColors.secondary)),
        )),
      ]),
    ),
  );
}
''' + s[end:]
s = s.replace('child: _DayButton(\n                label:', 'child: AspectRatio(aspectRatio: 1, child: _DayButton(\n                semanticLabel: MaterialLocalizations.of(context).formatFullDate(DateTime(2026, 9, 7 + day - 1)),\n                label:')
s = s.replace('''                },
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthDayGrid''', '''                },
              )),
            ),
          ),
      ],
    );
  }
}

class _MonthDayGrid''')
s = s.replace('class _DayButton extends StatelessWidget {', 'class _DayButton extends StatelessWidget {')
s = s.replace('''class _DayButton extends StatelessWidget {
  const _DayButton({''', '''class _DayButton extends StatelessWidget {
  const _DayButton({
    this.semanticLabel,''')
s = s.replace('''  final bool selected;
  final VoidCallback onPressed;''', '''  final bool selected;
  final String? semanticLabel;
  final VoidCallback onPressed;''')
pos = s.index('class _DayButton')
s = s[:pos] + s[pos:].replace('label: label,', 'label: semanticLabel ?? label,').replace('constraints: const BoxConstraints(minHeight: 44),', '')
p.write_text(s)
