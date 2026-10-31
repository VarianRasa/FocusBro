import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/task_service.dart';
import '../utils/accessibility_helper.dart';
import '../utils/error_handler.dart';
import '../utils/validation_helper.dart';

/// Task creation dialog
class CreateTaskDialog extends StatefulWidget {
  final Task? editingTask;

  const CreateTaskDialog({super.key, this.editingTask});

  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();

  TaskPriority _selectedPriority = TaskPriority.medium;
  TaskCategory _selectedCategory = TaskCategory.other;
  DateTime? _selectedDueDate;
  TimeOfDay? _selectedDueTime;
  int _estimatedSessions = 1;
  bool _isRecurring = false;
  String? _recurringPattern;
  bool _isLoading = false;

  // Enhanced scheduling features
  String _schedulingMode = 'specific'; // 'specific', 'relative', 'preset'
  String? _selectedPreset;
  int _relativeValue = 1;
  String _relativeUnit = 'hours'; // 'minutes', 'hours', 'days', 'weeks'
  bool _enableNotifications = false;
  int _notificationMinutes = 15;

  @override
  void initState() {
    super.initState();
    if (widget.editingTask != null) {
      _populateFields(widget.editingTask!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _populateFields(Task task) {
    _titleController.text = task.title;
    _descriptionController.text = task.description;
    _tagsController.text = task.tags.join(', ');
    _selectedPriority = task.priority;
    _selectedCategory = task.category;
    _selectedDueDate = task.dueDate;
    _estimatedSessions = task.estimatedFocusSessions;
    _isRecurring = task.isRecurring;
    _recurringPattern = task.recurringPattern;

    if (task.dueDate != null) {
      _selectedDueTime = TimeOfDay.fromDateTime(task.dueDate!);

      // Set scheduling mode to specific when editing existing task with due date
      _schedulingMode = 'specific';

      // Enable notifications by default for tasks with due dates
      _enableNotifications = true;
    } else {
      // No due date, keep default scheduling mode
      _schedulingMode = 'specific';
      _enableNotifications = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.editingTask != null;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: screenWidth * 0.9,
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.85, // Use 85% of screen height
          maxWidth: 500, // Maximum width for larger screens
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header - Fixed at top
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit : Icons.add_task,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Task' : 'Create New Task',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Divider
            Divider(
              height: 1,
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),

            // Form Content - Scrollable
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title Field
                      AccessibilityHelper.accessibleTextField(
                        controller: _titleController,
                        label: 'Task Title',
                        hint: 'Enter task title',
                        semanticHint: 'Required field for task title',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Task title is required';
                          }
                          if (!ValidationHelper.isValidTaskTitle(value)) {
                            return 'Please enter a valid task title';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Description Field
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                          hintText: 'Add task description...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (!ValidationHelper.isValidTaskDescription(
                                value)) {
                              return 'Description is too long';
                            }
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Priority and Category Row
                      Row(
                        children: [
                          // Priority Selector
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Priority',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<TaskPriority>(
                                  value: _selectedPriority,
                                  isExpanded: true, // Prevent overflow
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: TaskPriority.values.map((priority) {
                                    return DropdownMenuItem(
                                      value: priority,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            priority.icon,
                                            size: 16,
                                            color: priority.color,
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              priority.displayName,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _selectedPriority = value);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Category Selector
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Category',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<TaskCategory>(
                                  value: _selectedCategory,
                                  isExpanded: true, // Prevent overflow
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: TaskCategory.values.map((category) {
                                    return DropdownMenuItem(
                                      value: category,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            category.icon,
                                            size: 16,
                                            color: category.color,
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              category.displayName,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _selectedCategory = value);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Enhanced Scheduling Section
                      _buildEnhancedSchedulingSection(theme),

                      const SizedBox(height: 16),

                      // Estimated Focus Sessions
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estimated Focus Sessions',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton(
                                onPressed: _estimatedSessions > 1
                                    ? () => setState(() => _estimatedSessions--)
                                    : null,
                                icon: const Icon(Icons.remove),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: theme.colorScheme.outline,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$_estimatedSessions',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _estimatedSessions < 20
                                    ? () => setState(() => _estimatedSessions++)
                                    : null,
                                icon: const Icon(Icons.add),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'session${_estimatedSessions > 1 ? 's' : ''}',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Tags Field
                      TextFormField(
                        controller: _tagsController,
                        decoration: const InputDecoration(
                          labelText: 'Tags (Optional)',
                          hintText: 'Enter tags separated by commas',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.tag),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Recurring Task Toggle
                      Row(
                        children: [
                          AccessibilityHelper.accessibleSwitch(
                            value: _isRecurring,
                            label: 'Recurring Task',
                            hint: 'Enable to make this a recurring task',
                            onChanged: (value) =>
                                setState(() => _isRecurring = value),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Action Buttons - Fixed at bottom
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveTask,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isEditing ? 'Update Task' : 'Create Task'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedSchedulingSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Icon(
              Icons.schedule,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Schedule & Timing',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Scheduling Mode Selector
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Mode Tabs
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withAlpha(128),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    _buildModeTab('specific', 'Specific Date & Time',
                        Icons.calendar_today, theme),
                    _buildModeTab('preset', 'Quick Presets',
                        Icons.schedule_outlined, theme),
                    _buildModeTab('relative', 'Relative Time',
                        Icons.timer_outlined, theme),
                  ],
                ),
              ),

              // Mode Content
              Container(
                padding: const EdgeInsets.all(16),
                child: _buildSchedulingModeContent(theme),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Notification Settings
        _buildNotificationSettings(theme),
      ],
    );
  }

  Widget _buildModeTab(
      String mode, String label, IconData icon, ThemeData theme) {
    final isSelected = _schedulingMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _schedulingMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSchedulingModeContent(ThemeData theme) {
    switch (_schedulingMode) {
      case 'specific':
        return _buildSpecificDateTimeContent(theme);
      case 'preset':
        return _buildPresetContent(theme);
      case 'relative':
        return _buildRelativeTimeContent(theme);
      default:
        return _buildSpecificDateTimeContent(theme);
    }
  }

  Widget _buildSpecificDateTimeContent(ThemeData theme) {
    return Column(
      children: [
        // Date and Time Row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Due Date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _selectDueDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: theme.colorScheme.onSurface.withAlpha(153),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedDueDate != null
                                  ? '${_selectedDueDate!.day}/${_selectedDueDate!.month}/${_selectedDueDate!.year}'
                                  : 'Select date',
                              style: TextStyle(
                                color: _selectedDueDate != null
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurface
                                        .withAlpha(153),
                              ),
                            ),
                          ),
                          if (_selectedDueDate != null)
                            InkWell(
                              onTap: () => setState(() {
                                _selectedDueDate = null;
                                _selectedDueTime = null;
                              }),
                              child: const Icon(Icons.clear, size: 16),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Due Time',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _selectedDueDate != null ? _selectDueTime : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: _selectedDueDate != null
                                ? theme.colorScheme.onSurface.withAlpha(153)
                                : theme.colorScheme.onSurface.withAlpha(77),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedDueTime != null
                                  ? _selectedDueTime!.format(context)
                                  : 'Select time',
                              style: TextStyle(
                                color: _selectedDueTime != null
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurface
                                        .withAlpha(153),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() => _selectedDueDate = date);
    }
  }

  Future<void> _selectDueTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedDueTime ?? TimeOfDay.now(),
    );

    if (time != null) {
      setState(() => _selectedDueTime = time);
    }
  }

  Widget _buildPresetContent(ThemeData theme) {
    final presets = [
      {'label': 'Today', 'value': 'today', 'icon': Icons.today},
      {'label': 'Tomorrow', 'value': 'tomorrow', 'icon': Icons.event},
      {'label': 'This Weekend', 'value': 'weekend', 'icon': Icons.weekend},
      {'label': 'Next Week', 'value': 'next_week', 'icon': Icons.date_range},
      {
        'label': 'Next Month',
        'value': 'next_month',
        'icon': Icons.calendar_month
      },
    ];

    return Column(
      children: [
        Text(
          'Choose a quick preset for scheduling',
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withAlpha(179),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((preset) {
            final isSelected = _selectedPreset == preset['value'];
            return InkWell(
              onTap: () => _selectPreset(preset['value'] as String),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surface,
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      preset['icon'] as IconData,
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      preset['label'] as String,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRelativeTimeContent(ThemeData theme) {
    return Column(
      children: [
        Text(
          'Set a relative time from now',
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withAlpha(179),
          ),
        ),
        const SizedBox(height: 16),

        // Responsive layout that stacks on smaller screens
        LayoutBuilder(
          builder: (context, constraints) {
            // If width is too small, use vertical layout
            if (constraints.maxWidth < 280) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Duration',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildValueSelector(theme),
                      const SizedBox(width: 8),
                      Expanded(child: _buildUnitSelector(theme)),
                    ],
                  ),
                ],
              );
            } else {
              // Use horizontal layout for wider screens
              return Row(
                children: [
                  Text(
                    'In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildValueSelector(theme),
                  const SizedBox(width: 8),
                  Expanded(child: _buildUnitSelector(theme)),
                ],
              );
            }
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withAlpha(128),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Due: ${_getRelativeTimeDescription()}',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildValueSelector(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Compact decrease button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _relativeValue > 1
                    ? () => setState(() => _relativeValue--)
                    : null,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
                child: Container(
                  width: 32,
                  height: 40,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.remove,
                    size: 16,
                    color: _relativeValue > 1
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withAlpha(128),
                  ),
                ),
              ),
            ),

            // Value display
            Container(
              constraints: const BoxConstraints(minWidth: 32),
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.symmetric(
                  vertical: BorderSide(
                    color: theme.colorScheme.outline.withAlpha(128),
                    width: 0.5,
                  ),
                ),
              ),
              child: Text(
                '$_relativeValue',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),

            // Compact increase button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _relativeValue++),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                child: Container(
                  width: 32,
                  height: 40,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.add,
                    size: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitSelector(ThemeData theme) {
    return DropdownButtonFormField<String>(
      value: _relativeUnit,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      items: const [
        DropdownMenuItem(value: 'minutes', child: Text('Min')),
        DropdownMenuItem(value: 'hours', child: Text('Hours')),
        DropdownMenuItem(value: 'days', child: Text('Days')),
        DropdownMenuItem(value: 'weeks', child: Text('Weeks')),
      ],
      onChanged: (value) => setState(() => _relativeUnit = value!),
    );
  }

  Widget _buildNotificationSettings(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Notifications & Reminders',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Switch(
                value: _enableNotifications,
                onChanged: (value) =>
                    setState(() => _enableNotifications = value),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Enable task reminders',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          if (_enableNotifications) ...[
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reminder timing',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<int>(
                    value: _notificationMinutes,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      prefixIcon: Icon(
                        Icons.alarm,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5 min before')),
                      DropdownMenuItem(value: 15, child: Text('15 min before')),
                      DropdownMenuItem(value: 30, child: Text('30 min before')),
                      DropdownMenuItem(value: 60, child: Text('1 hour before')),
                      DropdownMenuItem(
                          value: 1440, child: Text('1 day before')),
                    ],
                    onChanged: (value) =>
                        setState(() => _notificationMinutes = value!),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _selectPreset(String preset) {
    setState(() {
      _selectedPreset = preset;
      final now = DateTime.now();

      switch (preset) {
        case 'today':
          _selectedDueDate = now;
          _selectedDueTime = TimeOfDay(hour: 17, minute: 0); // 5 PM
          break;
        case 'tomorrow':
          _selectedDueDate = now.add(const Duration(days: 1));
          _selectedDueTime = TimeOfDay(hour: 9, minute: 0); // 9 AM
          break;
        case 'weekend':
          final daysUntilSaturday = (6 - now.weekday) % 7;
          _selectedDueDate = now.add(
              Duration(days: daysUntilSaturday == 0 ? 7 : daysUntilSaturday));
          _selectedDueTime = TimeOfDay(hour: 10, minute: 0); // 10 AM
          break;
        case 'next_week':
          final daysUntilNextMonday = (8 - now.weekday) % 7;
          _selectedDueDate = now.add(Duration(
              days: daysUntilNextMonday == 0 ? 7 : daysUntilNextMonday));
          _selectedDueTime = TimeOfDay(hour: 9, minute: 0); // 9 AM
          break;
        case 'next_month':
          _selectedDueDate = DateTime(now.year, now.month + 1, 1);
          _selectedDueTime = TimeOfDay(hour: 9, minute: 0); // 9 AM
          break;
      }
    });
  }

  String _getRelativeTimeDescription() {
    final now = DateTime.now();
    Duration duration;

    switch (_relativeUnit) {
      case 'minutes':
        duration = Duration(minutes: _relativeValue);
        break;
      case 'hours':
        duration = Duration(hours: _relativeValue);
        break;
      case 'days':
        duration = Duration(days: _relativeValue);
        break;
      case 'weeks':
        duration = Duration(days: _relativeValue * 7);
        break;
      default:
        duration = Duration(hours: _relativeValue);
    }

    final dueDateTime = now.add(duration);
    return '${dueDateTime.day}/${dueDateTime.month}/${dueDateTime.year} at ${TimeOfDay.fromDateTime(dueDateTime).format(context)}';
  }

  DateTime? _calculateDueDateTime() {
    switch (_schedulingMode) {
      case 'specific':
        if (_selectedDueDate != null) {
          return DateTime(
            _selectedDueDate!.year,
            _selectedDueDate!.month,
            _selectedDueDate!.day,
            _selectedDueTime?.hour ?? 23,
            _selectedDueTime?.minute ?? 59,
          );
        }
        return null;

      case 'preset':
        if (_selectedDueDate != null && _selectedDueTime != null) {
          return DateTime(
            _selectedDueDate!.year,
            _selectedDueDate!.month,
            _selectedDueDate!.day,
            _selectedDueTime!.hour,
            _selectedDueTime!.minute,
          );
        }
        return null;

      case 'relative':
        final now = DateTime.now();
        Duration duration;

        switch (_relativeUnit) {
          case 'minutes':
            duration = Duration(minutes: _relativeValue);
            break;
          case 'hours':
            duration = Duration(hours: _relativeValue);
            break;
          case 'days':
            duration = Duration(days: _relativeValue);
            break;
          case 'weeks':
            duration = Duration(days: _relativeValue * 7);
            break;
          default:
            duration = Duration(hours: _relativeValue);
        }

        return now.add(duration);

      default:
        return null;
    }
  }

  bool _validateScheduling() {
    switch (_schedulingMode) {
      case 'specific':
        // For specific mode, due date is optional but if set, should be in the future
        if (_selectedDueDate != null) {
          final dueDateTime = _calculateDueDateTime();
          if (dueDateTime != null && dueDateTime.isBefore(DateTime.now())) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Due date/time cannot be in the past'),
                backgroundColor: Colors.red,
              ),
            );
            return false;
          }
        }
        return true;

      case 'preset':
        if (_selectedPreset == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a preset option'),
              backgroundColor: Colors.orange,
            ),
          );
          return false;
        }
        return true;

      case 'relative':
        if (_relativeValue <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Relative time value must be greater than 0'),
              backgroundColor: Colors.orange,
            ),
          );
          return false;
        }
        return true;

      default:
        return true;
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate scheduling settings
    if (!_validateScheduling()) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final taskService = TaskService();

      // Calculate due date/time based on scheduling mode
      DateTime? dueDateTime = _calculateDueDateTime();

      // Debug logging for scheduling
      debugPrint('CreateTaskDialog: Scheduling mode: $_schedulingMode');
      debugPrint('CreateTaskDialog: Calculated due date/time: $dueDateTime');
      if (_enableNotifications) {
        debugPrint(
            'CreateTaskDialog: Notifications enabled, reminder: $_notificationMinutes minutes before');
      }

      // Parse tags
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      if (widget.editingTask != null) {
        // Update existing task
        final updatedTask = widget.editingTask!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _selectedPriority,
          category: _selectedCategory,
          dueDate: dueDateTime,
          tags: tags,
          estimatedFocusSessions: _estimatedSessions,
          isRecurring: _isRecurring,
          recurringPattern: _isRecurring ? _recurringPattern : null,
        );

        await taskService.updateTask(updatedTask);

        if (mounted) {
          ErrorHandler.showSuccess(context, 'Task updated successfully');
          Navigator.pop(context, updatedTask);
        }
      } else {
        // Create new task
        final task = await taskService.createTask(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _selectedPriority,
          category: _selectedCategory,
          dueDate: dueDateTime,
          tags: tags,
          estimatedFocusSessions: _estimatedSessions,
          isRecurring: _isRecurring,
          recurringPattern: _isRecurring ? _recurringPattern : null,
        );

        if (mounted) {
          ErrorHandler.showSuccess(context, 'Task created successfully');
          Navigator.pop(context, task);
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'Failed to save task: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// Quick add task dialog
class QuickAddTaskDialog extends StatefulWidget {
  const QuickAddTaskDialog({super.key});

  @override
  State<QuickAddTaskDialog> createState() => _QuickAddTaskDialogState();
}

class _QuickAddTaskDialogState extends State<QuickAddTaskDialog> {
  final _titleController = TextEditingController();
  TaskPriority _selectedPriority = TaskPriority.medium;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Add Task',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'What needs to be done?',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (_) => _quickAddTask(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Priority:',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 12),
                ...TaskPriority.values.map((priority) {
                  final isSelected = _selectedPriority == priority;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(priority.displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedPriority = priority);
                        }
                      },
                      avatar: Icon(
                        priority.icon,
                        size: 16,
                        color: isSelected ? Colors.white : priority.color,
                      ),
                      selectedColor: priority.color,
                      checkmarkColor: Colors.white,
                    ),
                  );
                }).toList(),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _quickAddTask,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add Task'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _quickAddTask() async {
    if (_titleController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final taskService = TaskService();
      final task = await taskService.createTask(
        title: _titleController.text.trim(),
        priority: _selectedPriority,
      );

      if (mounted) {
        ErrorHandler.showSuccess(context, 'Task added successfully');
        Navigator.pop(context, task);
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'Failed to add task');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
