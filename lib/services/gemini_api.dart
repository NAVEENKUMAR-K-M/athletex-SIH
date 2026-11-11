class GeminiApi {
  static Future<Map<String, dynamic>> callGeminiApi(String prompt) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    if (prompt.contains("diet")) {
      return {
        'summary': "Your current diet is high in simple carbohydrates and lacks sufficient protein for muscle repair, crucial for a weightlifter. This optimized plan focuses on complex carbs for sustained energy and increases protein intake, with an emphasis on paneer, dal, and lean meats.",
        'newPlan': {
          'breakfast': "3-egg scramble with spinach, 1 bowl of oatmeal with nuts.",
          'lunch': "Large bowl of chicken or paneer curry with brown rice and a side of salad.",
          'dinner': "Grilled fish or tofu with roasted sweet potatoes and broccoli.",
          'snacks': "Greek yogurt, handful of almonds, a banana."
        }
      };
    } else if (prompt.contains("workout")) {
      return {
        'summary': "Your current workout plan is a good start but lacks structure for progressive overload. The recommended 'Push/Pull/Legs' split ensures all muscle groups are targeted effectively with adequate recovery time, which is essential for strength gains.",
        'newPlan': {
          'monday': "Push Day: Barbell Bench Press, Overhead Press, Tricep Pushdowns.",
          'tuesday': "Pull Day: Deadlifts, Pull-ups, Barbell Rows, Bicep Curls.",
          'wednesday': "Active Recovery: Light cardio (jogging/cycling), full-body stretching.",
          'thursday': "Leg Day: Barbell Squats, Romanian Deadlifts, Lunges, Calf Raises.",
          'friday': "Full Body Power: Power Cleans, Kettlebell Swings, Box Jumps."
        }
      };
    } else if (prompt.contains("performance")) {
      return {
        'insights': "Your form score of 85 is solid, but the AI flagged a key area for improvement. The 'incomplete range of motion' on later reps suggests fatigue is causing you to shorten your movements.\n\n**Actionable Tip:** Focus on controlling the weight throughout the entire lift, especially on the negative (lowering) phase. If you can't maintain full range, consider lowering the weight slightly to ensure quality over quantity."
      };
    }
    return {'summary': "No analysis available.", 'newPlan': {}};
  }
}
