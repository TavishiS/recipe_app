import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  // Ensure Flutter bindings are initialized before calling async methods
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load the environment variables from the .env file
  await dotenv.load(fileName: ".env");
  
  runApp(const RecipeApp());
}

class RecipeApp extends StatelessWidget {
  const RecipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leftover Chef',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const RecipeHomePage(),
    );
  }
}

class RecipeHomePage extends StatefulWidget {
  const RecipeHomePage({super.key});

  @override
  State<RecipeHomePage> createState() => _RecipeHomePageState();
}

class _RecipeHomePageState extends State<RecipeHomePage> {
  final TextEditingController _ingredientController = TextEditingController();
  final List<String> _ingredients = [];
  
  // Cache to store previously searched ingredient combinations
  final Map<String, String> _recipeCache = {};
  
  bool _isLoading = false;
  String _generatedRecipes = '';

  // Add ingredient to the list
  void _addIngredient() {
    final text = _ingredientController.text.trim().toLowerCase();
    if (text.isNotEmpty && !_ingredients.contains(text)) {
      setState(() {
        _ingredients.add(text);
        _ingredientController.clear();
      });
    }
  }

  // Remove ingredient from the list
  void _removeIngredient(String ingredient) {
    setState(() {
      _ingredients.remove(ingredient);
    });
  }

  // Generate Cache Key (Sorts ingredients so order doesn't matter)
  String _getCacheKey() {
    List<String> sortedIngredients = List.from(_ingredients)..sort();
    return sortedIngredients.join(',');
  }

  // Call Gemini API or fetch from Cache
  Future<void> _generateRecipes() async {
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one ingredient.')),
      );
      return;
    }

    // Securely fetch the API key from the loaded .env file
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    
    if (apiKey == null || apiKey.isEmpty) {
      setState(() {
        _generatedRecipes = 'Error: API Key not found. Please check your .env file.';
      });
      return;
    }

    final cacheKey = _getCacheKey();

    // 1. Check Cache First
    if (_recipeCache.containsKey(cacheKey)) {
      setState(() {
        _generatedRecipes = "⚡ (Loaded from Cache)\n\n${_recipeCache[cacheKey]!}";
      });
      return;
    }

    // 2. If not in cache, call Gemini
    setState(() {
      _isLoading = true;
      _generatedRecipes = '';
    });

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      final ingredientsList = _ingredients.join(', ');
      final prompt = '''
        I have the following leftover ingredients: $ingredientsList. 
        Please generate 5 recipe ideas using mostly these ingredients. 
        CRITICAL HEALTH RULE: Do not combine ingredients that are harmful or generally advised against consuming together in traditional or medical guidelines (e.g., do not mix milk with curd, milk with citrus, etc.). If my list contains clashing ingredients, warn me and omit the harmful combination from the recipes.
        Format the output clearly.
      ''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      final resultText = response.text ?? 'Could not generate recipes.';

      // 3. Save to Cache and update UI
      setState(() {
        _recipeCache[cacheKey] = resultText;
        _generatedRecipes = resultText;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _generatedRecipes = 'Error connecting to AI: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leftover Chef AI'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Input Field and Add Button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ingredientController,
                    decoration: const InputDecoration(
                      hintText: 'Enter an ingredient (e.g., Tomato)',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addIngredient(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle, size: 40, color: Colors.deepOrange),
                  onPressed: _addIngredient,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Dynamic Ingredient Chips
            Wrap(
              spacing: 8.0,
              children: _ingredients.map((ingredient) {
                return Chip(
                  label: Text(ingredient),
                  onDeleted: () => _removeIngredient(ingredient),
                  deleteIcon: const Icon(Icons.cancel),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Generate Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateRecipes,
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('Generate 5 Recipes'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            // Results Area
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Text(
                        _generatedRecipes,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}