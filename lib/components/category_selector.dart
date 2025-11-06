import 'package:flutter/material.dart';
import 'package:pica_comic/components/components.dart';

class CategorySelector extends StatefulWidget {
  final List<String> categories;
  final List<String> selectedCategories;
  final Function(List<String>) onCategoriesChanged;
  final String title;

  const CategorySelector({
    Key? key,
    required this.categories,
    required this.selectedCategories,
    required this.onCategoriesChanged,
    this.title = "分类",
  }) : super(key: key);

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  bool _expanded = false;
  
  void _toggleCategory(String category) {
    setState(() {
      if (widget.selectedCategories.contains(category)) {
        widget.selectedCategories.remove(category);
      } else {
        widget.selectedCategories.add(category);
      }
      widget.onCategoriesChanged(widget.selectedCategories);
    });
  }

  void _selectAll() {
    setState(() {
      widget.selectedCategories.clear();
      widget.selectedCategories.addAll(widget.categories);
      widget.onCategoriesChanged(widget.selectedCategories);
    });
  }

  void _clearAll() {
    setState(() {
      widget.selectedCategories.clear();
      widget.onCategoriesChanged(widget.selectedCategories);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题和展开按钮
        Row(
          children: [
            Text(
              "${widget.title} (${widget.selectedCategories.length}/${widget.categories.length})",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () {
                setState(() {
                  _expanded = !_expanded;
                });
              },
            ),
          ],
        ),
        
        if (_expanded) ...[
          const SizedBox(height: 8),
          
          // 全选/取消全选按钮
          Row(
            children: [
              TextButton(
                onPressed: _selectAll,
                child: const Text("全选"),
              ),
              TextButton(
                onPressed: _clearAll,
                child: const Text("取消全选"),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // 分类选择器
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.categories.map<Widget>((category) {
              final isSelected = widget.selectedCategories.contains(category);
              return FilterChipFixedWidth(
                label: Text(category),
                selected: isSelected,
                onSelected: (selected) => _toggleCategory(category),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          // 确定按钮
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _expanded = false;
                });
              },
              child: const Text("确定"),
            ),
          ),
        ],
      ],
    );
  }
}

// 分类选择器对话框
class CategorySelectorDialog extends StatefulWidget {
  final List<String> categories;
  final List<String> initialSelectedCategories;
  final Function(List<String>) onCategoriesSelected;

  const CategorySelectorDialog({
    Key? key,
    required this.categories,
    required this.initialSelectedCategories,
    required this.onCategoriesSelected,
  }) : super(key: key);

  @override
  State<CategorySelectorDialog> createState() => _CategorySelectorDialogState();
}

class _CategorySelectorDialogState extends State<CategorySelectorDialog> {
  late List<String> _selectedCategories;

  @override
  void initState() {
    super.initState();
    _selectedCategories = List.from(widget.initialSelectedCategories);
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedCategories.clear();
      _selectedCategories.addAll(widget.categories);
    });
  }

  void _clearAll() {
    setState(() {
      _selectedCategories.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Text("选择分类"),
          const Spacer(),
          Text(
            "(${_selectedCategories.length}/${widget.categories.length})",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 全选/取消全选按钮
            Row(
              children: [
                TextButton(
                  onPressed: _selectAll,
                  child: const Text("全选"),
                ),
                TextButton(
                  onPressed: _clearAll,
                  child: const Text("取消全选"),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 分类选择器
            SizedBox(
              height: 300,
              child: SingleChildScrollView(
                child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.categories.map<Widget>((category) {
                       final isSelected = _selectedCategories.contains(category);
                       return FilterChipFixedWidth(
                         label: Text(category),
                         selected: isSelected,
                         onSelected: (selected) => _toggleCategory(category),
                       );
                     }).toList(),
                  ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text("取消"),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onCategoriesSelected(_selectedCategories);
            Navigator.of(context).pop();
          },
          child: const Text("确定"),
        ),
      ],
    );
  }
}