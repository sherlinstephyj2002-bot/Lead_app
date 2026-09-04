import 'package:flutter/material.dart';

/// Clean, professional single-select dropdown supporting typing/searching, scrolling,
/// and proper disabled/required states.
class SearchableSingleSelectDropdown<T> extends StatelessWidget {
  final String label;
  final String hint;
  final List<T> items;
  final T? selectedItem;
  final String Function(T) itemAsString;
  final String Function(T)? itemAsSubTitle;
  final ValueChanged<T?> onChanged;
  final bool enabled;
  final bool isRequired;
  final IconData icon;
  final String? validatorError;

  const SearchableSingleSelectDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.items,
    required this.selectedItem,
    required this.itemAsString,
    this.itemAsSubTitle,
    required this.onChanged,
    this.enabled = true,
    this.isRequired = true,
    this.icon = Icons.arrow_drop_down_circle_outlined,
    this.validatorError,
  });

  void _openSelectionModal(BuildContext context) {
    if (!enabled) return;
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final filteredItems = items.where((item) {
              if (searchQuery.trim().isEmpty) return true;
              final name = itemAsString(item).toLowerCase();
              final sub = itemAsSubTitle != null ? itemAsSubTitle!(item).toLowerCase() : '';
              final query = searchQuery.trim().toLowerCase();
              return name.contains(query) || sub.contains(query);
            }).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(icon, color: const Color(0xFF5B4CF0), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    label.replaceAll('*', '').trim(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: filteredItems.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Text('No options available.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredItems.length,
                                itemBuilder: (context, index) {
                                  final item = filteredItems[index];
                                  final isSelected = selectedItem == item;
                                  final title = itemAsString(item);
                                  final subtitle = itemAsSubTitle != null ? itemAsSubTitle!(item) : null;

                                  return ListTile(
                                    dense: true,
                                    selected: isSelected,
                                    selectedTileColor: const Color(0xFF5B4CF0).withValues(alpha: 0.08),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 13)),
                                    subtitle: subtitle != null && subtitle.isNotEmpty
                                        ? Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey))
                                        : null,
                                    trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF5B4CF0), size: 18) : null,
                                    onTap: () {
                                      onChanged(item);
                                      Navigator.pop(ctx);
                                    },
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = selectedItem;
    final selectedText = item != null ? itemAsString(item) : '';

    return InkWell(
      onTap: enabled ? () => _openSelectionModal(context) : null,
      borderRadius: BorderRadius.circular(10),
      child: FormField<T>(
        initialValue: selectedItem,
        validator: (_) {
          if (isRequired && selectedItem == null) {
            return validatorError ?? 'Selection required';
          }
          return null;
        },
        builder: (state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              InputDecorator(
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: enabled
                        ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                        : const Color(0xFFCBD5E1),
                  ),
                  prefixIcon: Icon(
                    icon,
                    size: 18,
                    color: enabled
                        ? const Color(0xFF64748B)
                        : const Color(0xFFCBD5E1),
                  ),
                  suffixIcon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: enabled ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
                  ),
                  filled: true,
                  fillColor: enabled
                      ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC))
                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: state.hasError ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0)),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                child: Text(
                  selectedText.isNotEmpty ? selectedText : hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: selectedText.isNotEmpty ? FontWeight.w500 : FontWeight.normal,
                    color: enabled
                        ? (selectedText.isNotEmpty
                            ? (isDark ? Colors.white : const Color(0xFF1E293B))
                            : const Color(0xFF94A3B8))
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    state.errorText!,
                    style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Clean, professional multi-select dropdown supporting typing/searching, scrolling,
/// checkboxes, and summary text display.
class SearchableMultiSelectDropdown<T> extends StatelessWidget {
  final String label;
  final String hint;
  final List<T> items;
  final List<T> selectedItems;
  final String Function(T) itemAsString;
  final String Function(T)? itemAsSubTitle;
  final ValueChanged<List<T>> onChanged;
  final bool enabled;
  final IconData icon;

  const SearchableMultiSelectDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.items,
    required this.selectedItems,
    required this.itemAsString,
    this.itemAsSubTitle,
    required this.onChanged,
    this.enabled = true,
    this.icon = Icons.checklist_rounded,
  });

  void _openMultiSelectModal(BuildContext context) {
    if (!enabled) return;
    final tempSelected = List<T>.from(selectedItems);
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final filteredItems = items.where((item) {
              if (searchQuery.trim().isEmpty) return true;
              final name = itemAsString(item).toLowerCase();
              final sub = itemAsSubTitle != null ? itemAsSubTitle!(item).toLowerCase() : '';
              final query = searchQuery.trim().toLowerCase();
              return name.contains(query) || sub.contains(query);
            }).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(icon, color: const Color(0xFF5B4CF0), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    label.replaceAll('*', '').trim(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${tempSelected.length} Selected',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0)),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  tempSelected.clear();
                                  tempSelected.addAll(items);
                                });
                              },
                              child: const Text('Select All', style: TextStyle(fontSize: 11)),
                            ),
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  tempSelected.clear();
                                });
                              },
                              child: const Text('Clear All', style: TextStyle(fontSize: 11, color: Colors.red)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: filteredItems.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Text('No options found.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredItems.length,
                                itemBuilder: (context, index) {
                                  final item = filteredItems[index];
                                  final isChecked = tempSelected.contains(item);
                                  final title = itemAsString(item);
                                  final subtitle = itemAsSubTitle != null ? itemAsSubTitle!(item) : null;

                                  return CheckboxListTile(
                                    activeColor: const Color(0xFF5B4CF0),
                                    dense: true,
                                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    subtitle: subtitle != null && subtitle.isNotEmpty
                                        ? Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey))
                                        : null,
                                    value: isChecked,
                                    onChanged: (val) {
                                      setModalState(() {
                                        if (val == true) {
                                          tempSelected.add(item);
                                        } else {
                                          tempSelected.remove(item);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B4CF0),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    onChanged(tempSelected);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedNames = selectedItems.map(itemAsString).toList();

    String displayText = hint;
    if (selectedNames.isNotEmpty) {
      if (selectedNames.length <= 2) {
        displayText = selectedNames.join(', ');
      } else {
        displayText = '${selectedNames.length} Selected';
      }
    }

    return InkWell(
      onTap: enabled ? () => _openMultiSelectModal(context) : null,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: enabled
                ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                : const Color(0xFFCBD5E1),
          ),
          prefixIcon: Icon(
            icon,
            size: 18,
            color: enabled
                ? const Color(0xFF64748B)
                : const Color(0xFFCBD5E1),
          ),
          suffixIcon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: enabled ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
          ),
          filled: true,
          fillColor: enabled
              ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC))
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          displayText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: selectedNames.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
            color: enabled
                ? (selectedNames.isNotEmpty
                    ? const Color(0xFF5B4CF0)
                    : const Color(0xFF94A3B8))
                : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
