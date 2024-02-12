import 'dart:async';

import 'package:flutter/material.dart';

typedef String? FormFieldFormatter<T>(T? v);
typedef bool MaterialSearchFilter<T>(T? v, String c);
typedef int MaterialSearchSort<T>(T? a, T? b, String c);
typedef Future<List<MaterialSearchResult>> MaterialResultsFinder(String c);
typedef void OnSubmit(String? value);

class MaterialSearchResult<T> extends StatelessWidget {
  const MaterialSearchResult({
    Key? key,
    this.value,
    this.text,
    this.icon,
  }) : super(key: key);

  final T? value;
  final String? text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Row(
        children: <Widget>[
          Container(width: 70.0, child: Icon(icon)),
          Expanded(child: Text(text ?? '')),
        ],
      ),
      height: 56.0,
    );
  }
}

class MaterialSearch<T> extends StatefulWidget {
  MaterialSearch({
    Key? key,
    this.placeholder,
    this.results,
    this.getResults,
    this.filter,
    this.sort,
    this.limit = 10,
    this.onSelect,
    this.onSubmit,
    this.barBackgroundColor = Colors.white,
    this.iconColor = Colors.black,
    this.leading,
  }) : super(key: key);

  final String? placeholder;

  final List<MaterialSearchResult<T>>? results;
  final MaterialResultsFinder? getResults;
  final MaterialSearchFilter<T>? filter;
  final MaterialSearchSort<T>? sort;
  final int limit;
  final ValueChanged<T>? onSelect;
  final OnSubmit? onSubmit;
  final Color barBackgroundColor;
  final Color iconColor;
  final Widget? leading;

  @override
  _MaterialSearchState<T> createState() => _MaterialSearchState<T>();
}

class _MaterialSearchState<T> extends State<MaterialSearch> {
  bool _loading = false;
  List<MaterialSearchResult<T>> _results = [];

  String _criteria = '';
  TextEditingController _controller = TextEditingController();

  _filter(dynamic v, String c) {
    return v.toString().toLowerCase().trim()
        .contains(RegExp(r'' + c.toLowerCase().trim() + ''));
  }

  @override
  void initState() {
    super.initState();

    if (widget.getResults != null) {
      _getResultsDebounced();
    }

    _controller.addListener(() {
      setState(() {
        _criteria = _controller.value.text;
        if (widget.getResults != null) {
          _getResultsDebounced();
        }
      });
    });
  }

  Timer? _resultsTimer;
  Future _getResultsDebounced() async {
    if (_results.length == 0) {
      setState(() {
        _loading = true;
      });
    }

    if (_resultsTimer != null && _resultsTimer!.isActive) {
      _resultsTimer!.cancel();
    }

    _resultsTimer = Timer(Duration(milliseconds: 400), () async {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = true;
      });

      //TODO: debounce widget.results too
      var results = await widget.getResults!(_criteria);

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _results = results.cast<MaterialSearchResult<T>>();

      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _resultsTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    var results = (widget.results ?? _results)
        .where((MaterialSearchResult result) {
      if (widget.filter != null) {
        return widget.filter!(result.value, _criteria);
      }
      //only apply default filter if used the `results` option
      //because getResults may already have applied some filter if `filter` option was omited.
      else if (widget.results != null) {
        return _filter(result.value, _criteria);
      }

      return true;
    })
        .toList();

    if (widget.sort != null) {
      results.sort((a, b) => widget.sort!(a.value, b.value, _criteria));
    }

    results = results
        .take(widget.limit)
        .toList();

    IconThemeData iconTheme = Theme.of(context).iconTheme.copyWith(color: widget.iconColor);

    return Scaffold(
      appBar: AppBar(
        leading: widget.leading,
        backgroundColor: widget.barBackgroundColor,
        iconTheme: iconTheme,
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration.collapsed(hintText: widget.placeholder),
          style: Theme.of(context).textTheme.headline6,
          onSubmitted: (String value) {
            if (widget.onSubmit != null) {
              widget.onSubmit!(value);
            }
          },
        ),
        actions: _criteria.length == 0 ? [] : [
          IconButton(
              icon: Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _controller.text = _criteria = '';
                });
              }
          ),
        ],
      ),
      body: _loading
          ? Center(
        child: Padding(
            padding: const EdgeInsets.only(top: 50.0),
            child: CircularProgressIndicator()
        ),
      )
          : SingleChildScrollView(
        child: Column(
          children: results.map((MaterialSearchResult result) {
            return InkWell(
              onTap: () => widget.onSelect!(result.value),
              child: result,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _MaterialSearchPageRoute<T> extends MaterialPageRoute<T> {
  _MaterialSearchPageRoute({
    required WidgetBuilder builder,
    RouteSettings? settings = const RouteSettings(name: 'material_search'),
    bool maintainState = true,
    bool fullscreenDialog = false,
  }) : super(builder: builder, settings: settings, maintainState: maintainState, fullscreenDialog: fullscreenDialog);
}

class MaterialSearchInput<T> extends StatefulWidget {
  MaterialSearchInput({
    Key? key,
    this.onSaved,
    this.validator,
    this.placeholder,
    this.formatter,
    this.results,
    this.getResults,
    this.filter,
    this.sort,
    this.onSelect,
  });

  final FormFieldSetter<T>? onSaved;
  final FormFieldValidator<T>? validator;
  final String? placeholder;
  final FormFieldFormatter<T>? formatter;

  final List<MaterialSearchResult<T>>? results;
  final MaterialResultsFinder? getResults;
  final MaterialSearchFilter<T>? filter;
  final MaterialSearchSort<T>? sort;
  final ValueChanged<T>? onSelect;

  @override
  _MaterialSearchInputState<T> createState() => _MaterialSearchInputState<T>();
}

class _MaterialSearchInputState<T> extends State<MaterialSearchInput<T>> {
  GlobalKey<FormFieldState<T>> _formFieldKey = GlobalKey<FormFieldState<T>>();

  _buildMaterialSearchPage(BuildContext context) {
    return _MaterialSearchPageRoute<T>(
        settings: RouteSettings(
          name: 'material_search',
        ),
        builder: (BuildContext context) {
          return Material(
            child: MaterialSearch<T>(
              placeholder: widget.placeholder,
              results: widget.results,
              getResults: widget.getResults,
              filter: widget.filter,
              sort: widget.sort,
              onSelect: (dynamic value) => Navigator.of(context).pop(value),
            ),
          );
        }
    );
  }

  _showMaterialSearch(BuildContext context) {
    Navigator.of(context)
        .push(_buildMaterialSearchPage(context))
        .then((dynamic value) {
      if (value != null) {
        _formFieldKey.currentState!.didChange(value);
        widget.onSelect!(value);
      }
    });
  }

  bool _isEmpty(field) {
    return field.value == null;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showMaterialSearch(context),
      child: FormField<T>(
        key: _formFieldKey,
        validator: widget.validator,
        onSaved: widget.onSaved,
        autovalidateMode: AutovalidateMode.disabled,
        builder: (FormFieldState<T> field) {
          return InputDecorator(
            isEmpty: _isEmpty(field),
            decoration: InputDecoration(
              labelText: widget.placeholder,
              errorText: field.errorText,
            ),
            child: _isEmpty(field) ? null : Text(
                widget.formatter != null
                    ?( widget.formatter!(field.value) ?? "")
                    : (field.value ?? "").toString()
            ),
          );
        },
      ),
    );
  }
}
