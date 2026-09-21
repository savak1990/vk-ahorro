import 'package:flutter/material.dart';
import '../models/category.dart';
import 'package:ahorro_ui/src/widgets/category_picker_dialog.dart';

class TransactionItemRow extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController amountController;
  final String selectedCategoryId;
  final IconData? selectedCategoryIcon;
  final ValueChanged<Category> onCategorySelected;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onAmountChanged;
  final String? descriptionErrorText;
  final bool hasAmountError;
  final bool canRemove;
  final VoidCallback? onRemove;

  const TransactionItemRow({
    super.key,
    required this.nameController,
    required this.amountController,
    required this.selectedCategoryId,
    required this.selectedCategoryIcon,
    required this.onCategorySelected,
    required this.onNameChanged,
    required this.onAmountChanged,
    this.descriptionErrorText,
    this.hasAmountError = false,
    this.canRemove = false,
    this.onRemove,
  });

  Future<void> _handlePickCategory(BuildContext context) async {
    final selected = await showDialog<Category?>(
      context: context,
      builder: (context) => CategoryPickerDialog(
        selectedCategoryId: selectedCategoryId,
      ),
    );
    if (selected != null) {
      onCategorySelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => _handlePickCategory(context),
              child: CircleAvatar(
                backgroundColor: cs.surfaceContainerHighest,
                child: selectedCategoryIcon != null
                    ? Icon(selectedCategoryIcon, color: cs.primary)
                    : Icon(Icons.category, color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                controller: nameController,
                onChanged: onNameChanged,
                decoration: InputDecoration(
                  hintText: 'Description',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: cs.primary, width: 2),
                  ),
                  errorText: descriptionErrorText,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: onAmountChanged,
                decoration: InputDecoration(
                  hintText: '0.00',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: hasAmountError ? cs.error : cs.outlineVariant,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: hasAmountError ? cs.error : cs.outlineVariant,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: hasAmountError ? cs.error : cs.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            if (canRemove)
              IconButton(
                icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade300),
                onPressed: onRemove,
                tooltip: 'Remove',
              ),
          ],
        ),
      ),
    );
  }
}