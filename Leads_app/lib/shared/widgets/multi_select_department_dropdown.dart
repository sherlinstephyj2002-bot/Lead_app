import 'package:flutter/material.dart';
import '../models/department_model.dart';

class MultiSelectDepartmentDropdown extends StatelessWidget {
  final List<DepartmentModel> departments;
  final List<String> selectedDepartmentIds;
  final ValueChanged<List<String>> onChanged;
  final String label;
  final String hint;

  const MultiSelectDepartmentDropdown({
    super.key,
    required this.departments,
    required this.selectedDepartmentIds,
    required this.onChanged,
    this.label = 'Departments *',
    this.hint = 'Select departments',
  });

  void _openMultiSelectModal(BuildContext context) {
    final tempSelected = List<String>.from(selectedDepartmentIds);
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final filteredDepts = departments.where((d) {
              if (searchQuery.trim().isEmpty) return true;
              return d.departmentName.toLowerCase().contains(searchQuery.trim().toLowerCase()) ||
                  d.departmentCode.toLowerCase().contains(searchQuery.trim().toLowerCase());
            }).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.business_center_rounded, color: Color(0xFF5B4CF0), size: 20),
                  const SizedBox(width: 8),
                  Text(label.replaceAll('*', '').trim(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search Bar
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search departments...',
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

                    // Select All / Clear All Row
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
                                  tempSelected.addAll(departments.map((d) => d.departmentId));
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

                    // Department Checkbox List
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: filteredDepts.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Text('No matching departments found.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredDepts.length,
                                itemBuilder: (context, index) {
                                  final dept = filteredDepts[index];
                                  final isChecked = tempSelected.contains(dept.departmentId);

                                  return CheckboxListTile(
                                    activeColor: const Color(0xFF5B4CF0),
                                    dense: true,
                                    title: Text(dept.departmentName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    subtitle: Text(dept.departmentCode, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    value: isChecked,
                                    onChanged: (val) {
                                      setModalState(() {
                                        if (val == true) {
                                          tempSelected.add(dept.departmentId);
                                        } else {
                                          tempSelected.remove(dept.departmentId);
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
    final selectedNames = departments
        .where((d) => selectedDepartmentIds.contains(d.departmentId))
        .map((d) => d.departmentName)
        .toList();

    return InkWell(
      onTap: () => _openMultiSelectModal(context),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.business_center_rounded, color: Color(0xFF5B4CF0), size: 20),
          suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: selectedNames.isEmpty
            ? Text(hint, style: const TextStyle(color: Colors.grey, fontSize: 14))
            : Wrap(
                spacing: 6,
                runSpacing: 4,
                children: selectedNames.map((name) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B4CF0).withValues(alpha: isDark ? 0.25 : 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF5B4CF0).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      name,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0)),
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }
}
