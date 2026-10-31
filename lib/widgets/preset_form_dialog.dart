import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/timer_preset.dart';
import '../providers/preset_provider.dart';

class PresetFormDialog extends StatefulWidget {
  final PresetProvider presetProvider;
  final TimerPreset? editingPreset;

  const PresetFormDialog({
    super.key,
    required this.presetProvider,
    this.editingPreset,
  });

  @override
  State<PresetFormDialog> createState() => _PresetFormDialogState();
}

class _PresetFormDialogState extends State<PresetFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _workDurationController = TextEditingController();
  final _breakDurationController = TextEditingController();
  final _sessionsController = TextEditingController();

  bool _isLoading = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    if (widget.editingPreset != null) {
      final preset = widget.editingPreset!;
      _nameController.text = preset.name;
      _workDurationController.text = (preset.workDuration ~/ 60).toString();
      _breakDurationController.text = (preset.breakDuration ~/ 60).toString();
      _sessionsController.text = preset.totalSessions.toString();
    } else {
      // Set default values for new preset
      _workDurationController.text = '25';
      _breakDurationController.text = '5';
      _sessionsController.text = '4';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _workDurationController.dispose();
    _breakDurationController.dispose();
    _sessionsController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.editingPreset != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Preset' : 'Create New Preset'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Preset Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Preset Name',
                  border: const OutlineInputBorder(),
                  errorText: _nameError,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a preset name';
                  }
                  if (value.trim().length > 50) {
                    return 'Name must be 50 characters or less';
                  }
                  return null;
                },
                onChanged: (value) {
                  if (_nameError != null) {
                    setState(() {
                      _nameError = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Work Duration
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _workDurationController,
                      decoration: const InputDecoration(
                        labelText: 'Work Duration (min)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final minutes = int.tryParse(value);
                        if (minutes == null || minutes < 1 || minutes > 60) {
                          return '1-60 min';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _breakDurationController,
                      decoration: const InputDecoration(
                        labelText: 'Break Duration (min)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final minutes = int.tryParse(value);
                        if (minutes == null || minutes < 1 || minutes > 60) {
                          return '1-60 min';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Total Sessions
              TextFormField(
                controller: _sessionsController,
                decoration: const InputDecoration(
                  labelText: 'Total Sessions',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter number of sessions';
                  }
                  final sessions = int.tryParse(value);
                  if (sessions == null || sessions < 1 || sessions > 20) {
                    return 'Must be between 1 and 20 sessions';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preview:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _buildPreviewText(),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _savePreset,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }

  String _buildPreviewText() {
    final name = _nameController.text.trim().isEmpty
        ? 'Untitled Preset'
        : _nameController.text.trim();
    final work = _workDurationController.text.isEmpty
        ? '0'
        : _workDurationController.text;
    final breakTime = _breakDurationController.text.isEmpty
        ? '0'
        : _breakDurationController.text;
    final sessions =
        _sessionsController.text.isEmpty ? '0' : _sessionsController.text;

    return '$name: ${work}min work • ${breakTime}min break • $sessions sessions';
  }

  Future<void> _savePreset() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _nameError = null;
    });

    try {
      final name = _nameController.text.trim();
      final workDuration = int.parse(_workDurationController.text) * 60;
      final breakDuration = int.parse(_breakDurationController.text) * 60;
      final totalSessions = int.parse(_sessionsController.text);

      bool success;
      if (_isEditing) {
        success = await widget.presetProvider.updatePreset(
          presetId: widget.editingPreset!.id!,
          name: name,
          workDuration: workDuration,
          breakDuration: breakDuration,
          totalSessions: totalSessions,
        );
      } else {
        success = await widget.presetProvider.createPreset(
          name: name,
          workDuration: workDuration,
          breakDuration: breakDuration,
          totalSessions: totalSessions,
        );
      }

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditing
                  ? 'Preset updated successfully'
                  : 'Preset created successfully'),
            ),
          );
        } else {
          // Check if it's a name validation error
          final error = widget.presetProvider.error;
          if (error != null && error.toLowerCase().contains('name')) {
            setState(() {
              _nameError = error;
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error ?? 'Failed to save preset'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
