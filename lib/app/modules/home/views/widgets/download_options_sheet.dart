import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/services/download_service.dart';

class DownloadOptionsSheet {
  DownloadOptionsSheet._();

  static Future<PreparedDownloadOption?> show(
    Future<PreparedDownload> Function() loader, {
    Color? barrierColor,
  }) {
    return Get.bottomSheet<PreparedDownloadOption>(
      _DownloadOptionsSheetBody(loader: loader),
      isScrollControlled: true,
      backgroundColor: AppColor.transparent,
      barrierColor: barrierColor ?? AppColor.scrim,
    );
  }
}

class _DownloadOptionsSheetBody extends StatefulWidget {
  const _DownloadOptionsSheetBody({required this.loader});

  final Future<PreparedDownload> Function() loader;

  @override
  State<_DownloadOptionsSheetBody> createState() =>
      _DownloadOptionsSheetBodyState();
}

class _DownloadOptionsSheetBodyState extends State<_DownloadOptionsSheetBody> {
  PreparedDownload? _preparedDownload;
  PreparedDownloadOption? _selectedOption;
  PreparedDownloadKind _activeKind = PreparedDownloadKind.video;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreparedDownload();
  }

  Future<void> _loadPreparedDownload() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final PreparedDownload preparedDownload = await widget.loader();
      if (!mounted) {
        return;
      }

      setState(() {
        _preparedDownload = preparedDownload;
        _selectedOption = preparedDownload.defaultOption;
        _activeKind = preparedDownload.defaultOption.kind;
        _isLoading = false;
      });
    } on DownloadServiceException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _preparedDownload = null;
        _selectedOption = null;
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _preparedDownload = null;
        _selectedOption = null;
        _errorMessage =
            'Something went wrong while collecting download details.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + bottomInset),
        decoration: BoxDecoration(
          color: AppColor.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: AppColor.stroke),
          boxShadow: const [
            BoxShadow(
              color: AppColor.shadow,
              blurRadius: 28,
              offset: Offset(0, -10),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _isLoading
              ? const _LoadingSheetContent()
              : _errorMessage != null
              ? _ErrorSheetContent(
                  message: _errorMessage!,
                  onRetry: _loadPreparedDownload,
                )
              : _OptionsSheetContent(
                  preparedDownload: _preparedDownload!,
                  selectedOption: _selectedOption!,
                  activeKind: _activeKind,
                  onKindChanged: (PreparedDownloadKind kind) {
                    setState(() {
                      _activeKind = kind;
                      _selectedOption = _preparedDownload!.options.firstWhere(
                        (PreparedDownloadOption option) => option.kind == kind,
                      );
                    });
                  },
                  onOptionSelected: (PreparedDownloadOption option) {
                    setState(() {
                      _selectedOption = option;
                    });
                  },
                ),
        ),
      ),
    );
  }
}

class _LoadingSheetContent extends StatelessWidget {
  const _LoadingSheetContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('loading'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 5,
          decoration: BoxDecoration(
            color: AppColor.stroke,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 18),
        const _PreviewCardSkeleton(),
        const SizedBox(height: 16),
        _SectionLabel(label: 'Download type'),
        const SizedBox(height: 8),
        const _DisabledTypeSelector(),
        const SizedBox(height: 14),
        _SectionLabel(label: 'Choose quality'),
        const SizedBox(height: 10),
        const _HintCard(
          message:
              'Select video, audio, and quality once the details finish loading.',
        ),
        const SizedBox(height: 10),
        const _LoadingOptionsList(),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColor.primarySoft,
              foregroundColor: AppColor.surface,
              disabledBackgroundColor: AppColor.primarySoft,
              disabledForegroundColor: AppColor.surface.withAlpha(170),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Loading Options...',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorSheetContent extends StatelessWidget {
  const _ErrorSheetContent({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('error'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 5,
          decoration: BoxDecoration(
            color: AppColor.stroke,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColor.surfaceSoft,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColor.stroke),
          ),
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColor.primarySoft,
                ),
                child: const Icon(
                  Icons.link_off_rounded,
                  color: AppColor.primaryDeep,
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Could Not Load Options',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  color: AppColor.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: AppColor.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Get.back<void>(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColor.stroke),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColor.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.primary,
                  foregroundColor: AppColor.surface,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  'Try Again',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OptionsSheetContent extends StatelessWidget {
  const _OptionsSheetContent({
    required this.preparedDownload,
    required this.selectedOption,
    required this.activeKind,
    required this.onKindChanged,
    required this.onOptionSelected,
  });

  final PreparedDownload preparedDownload;
  final PreparedDownloadOption selectedOption;
  final PreparedDownloadKind activeKind;
  final ValueChanged<PreparedDownloadKind> onKindChanged;
  final ValueChanged<PreparedDownloadOption> onOptionSelected;

  @override
  Widget build(BuildContext context) {
    final List<PreparedDownloadKind> availableKinds = preparedDownload.options
        .map((PreparedDownloadOption option) => option.kind)
        .toSet()
        .toList();
    final List<PreparedDownloadOption> visibleOptions = preparedDownload.options
        .where((PreparedDownloadOption option) => option.kind == activeKind)
        .toList();

    return Column(
      key: const ValueKey<String>('ready'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 5,
          decoration: BoxDecoration(
            color: AppColor.stroke,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 18),
        _PreviewCard(preparedDownload: preparedDownload),
        const SizedBox(height: 16),
        if (availableKinds.length > 1) ...[
          _SectionLabel(label: 'Download type'),
          const SizedBox(height: 8),
          _TypeSelector(
            activeKind: activeKind,
            availableKinds: availableKinds,
            onChanged: onKindChanged,
          ),
          const SizedBox(height: 14),
        ],
        _SectionLabel(label: 'Choose quality'),
        const SizedBox(height: 10),
        if (activeKind == PreparedDownloadKind.video) ...[
          const _HintCard(
            message:
                'Some higher YouTube qualities may be video-only. Entries labeled "Video + audio" include sound.',
          ),
          const SizedBox(height: 10),
        ],
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.31,
          ),
          child: SingleChildScrollView(
            child: Column(
              children: visibleOptions
                  .map(
                    (PreparedDownloadOption option) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _OptionTile(
                        option: option,
                        isSelected: selectedOption.id == option.id,
                        onTap: () => onOptionSelected(option),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () =>
                Get.back<PreparedDownloadOption>(result: selectedOption),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColor.primary,
              foregroundColor: AppColor.surface,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Download Selected',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          color: AppColor.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColor.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColor.stroke),
      ),
      child: Text(
        message,
        style: GoogleFonts.plusJakartaSans(
          color: AppColor.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }
}

class _PreviewCardSkeleton extends StatelessWidget {
  const _PreviewCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColor.surfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColor.stroke),
      ),
      child: Row(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: AppColor.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonLine(widthFactor: 0.24),
                const SizedBox(height: 10),
                _SkeletonLine(widthFactor: 0.92, height: 16),
                const SizedBox(height: 8),
                _SkeletonLine(widthFactor: 0.74, height: 16),
                const SizedBox(height: 10),
                _SkeletonLine(widthFactor: 0.38),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingOptionsList extends StatelessWidget {
  const _LoadingOptionsList();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.28,
      ),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: const Column(
          children: [
            _OptionTileSkeleton(),
            SizedBox(height: 10),
            _OptionTileSkeleton(),
            SizedBox(height: 10),
            _OptionTileSkeleton(),
          ],
        ),
      ),
    );
  }
}

class _DisabledTypeSelector extends StatelessWidget {
  const _DisabledTypeSelector();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColor.surfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColor.stroke),
      ),
      child: Row(
        children: const [
          Expanded(child: _DisabledTypeChip(label: 'Video', selected: true)),
          SizedBox(width: 6),
          Expanded(child: _DisabledTypeChip(label: 'Audio')),
        ],
      ),
    );
  }
}

class _DisabledTypeChip extends StatelessWidget {
  const _DisabledTypeChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: selected ? AppColor.primarySoft : AppColor.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.spaceGrotesk(
          color: selected ? AppColor.primaryDeep : AppColor.textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OptionTileSkeleton extends StatelessWidget {
  const _OptionTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColor.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColor.stroke),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonLine(widthFactor: 0.24, height: 16),
                SizedBox(height: 8),
                _SkeletonLine(widthFactor: 0.56),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColor.primarySoft,
              border: Border.all(color: AppColor.stroke),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.widthFactor, this.height = 12});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColor.primarySoft,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preparedDownload});

  final PreparedDownload preparedDownload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColor.surfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColor.stroke),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 78,
              height: 78,
              color: AppColor.surfaceDark,
              child: preparedDownload.thumbnailUrl != null
                  ? Image.network(
                      preparedDownload.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _ThumbnailFallback(),
                    )
                  : const _ThumbnailFallback(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preparedDownload.sourceLabel,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColor.primaryDeep,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  preparedDownload.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColor.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${preparedDownload.options.length} download option${preparedDownload.options.length == 1 ? '' : 's'}',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColor.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({
    required this.activeKind,
    required this.availableKinds,
    required this.onChanged,
  });

  final PreparedDownloadKind activeKind;
  final List<PreparedDownloadKind> availableKinds;
  final ValueChanged<PreparedDownloadKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColor.surfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColor.stroke),
      ),
      child: Row(
        children: availableKinds
            .map(
              (PreparedDownloadKind kind) => Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(kind),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: activeKind == kind
                          ? AppColor.primary
                          : AppColor.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      kind == PreparedDownloadKind.video ? 'Video' : 'Audio',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(
                        color: activeKind == kind
                            ? AppColor.surface
                            : AppColor.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final PreparedDownloadOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColor.primarySoft : AppColor.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected ? AppColor.primary : AppColor.stroke,
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.label,
                            style: GoogleFonts.spaceGrotesk(
                              color: AppColor.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _OptionBadge(
                          label: option.kind == PreparedDownloadKind.audio
                              ? 'AUDIO'
                              : option.subtitle.contains('Video + audio')
                              ? 'AV'
                              : 'VIDEO',
                          highlighted: isSelected,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      option.subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColor.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? AppColor.primary
                      : AppColor.primarySoft.withAlpha(120),
                  border: Border.all(
                    color: isSelected ? AppColor.primary : AppColor.stroke,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppColor.surface,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionBadge extends StatelessWidget {
  const _OptionBadge({required this.label, required this.highlighted});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColor.primary.withAlpha(18)
            : AppColor.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted ? AppColor.primary.withAlpha(70) : AppColor.stroke,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: highlighted ? AppColor.primaryDeep : AppColor.textSecondary,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ThumbnailFallback extends StatelessWidget {
  const _ThumbnailFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColor.surfaceDark, AppColor.primaryDeep],
        ),
      ),
      child: const Center(
        child: Icon(Icons.download_rounded, color: AppColor.surface, size: 32),
      ),
    );
  }
}
