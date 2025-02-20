return {
    Generate = {
        prompt = "$input,just output the final code without additional quotes around it:\n$text",
        replace = true,
    },
    Chat = { prompt = "$input" },
    Summarize = { prompt = "Summarize the following text:\n$text" },
    Ask = { prompt = "Here is the code:\n```$filetype\n$text\n```\n\n My question is: $input" },
    Change = {
        prompt = "Change the following code:\n```$filetype\n$text\n```\n\n,to my request: $input, just output the final code without additional quotes around it:\n$text",
        replace = true,
    },
    Enhance_Grammar_Spelling = {
        prompt = "Modify the following text to improve grammar and spelling, just output the final text without additional quotes around it:\n$text",
        replace = true,
    },
    Enhance_Wording = {
        prompt = "Modify the following text to use better wording, just output the final text without additional quotes around it:\n$text",
        replace = true,
    },
    Make_Concise = {
        prompt = "Modify the following text to make it as simple and concise as possible, just output the final text without additional quotes around it:\n$text",
        replace = true,
    },
    Make_List = {
        prompt = "Render the following text as a markdown list:\n$text",
        replace = true,
    },
    Make_Table = {
        prompt = "Render the following text as a markdown table:\n$text",
        replace = true,
    },
    Review_Code = {
        prompt = "Please review and analyze this code:\n```$filetype\n$text\n```\n\n, identify potential issues and identify potential areas for improvement related to code smells, readability, maintainability, performance, security, etc. Do not list issues already addressed in the given code. Focus on providing up to 5 constructive suggestions that could make the code more robust, efficient, or align with best practices. For each suggestion, provide a brief explanation of the potential benefits. After listing any recommendations, summarize if you found notable opportunities to enhance the code quality overall or if the code generally follows sound design principles. If no issues found, 'reply There are no errors'.",
    },
    Enhance_Code = {
        prompt = "Here is the code I want you to enhance:\n```$filetype\n$text\n```\n\n, only output the result in format ```$filetype\n...\n```:\n```$filetype\n$text\n```",
        replace = true,
        extract = "```$filetype\n(.-)```",
    },
    Fix_Code = {
        prompt = "Here is the code:\n```$filetype\n$text\n```\n\n,Fix the code and only output the result in format ```$filetype\n...\n```:\n```$filetype\n$text\n```",
        replace = true,
        extract = "```$filetype\n(.-)```",
    },
    Change_Code = {
        prompt = "Here is the code I want you to change, if there is no possible change for it then simply tell me there isn't any:\n```$filetype\n$text\n```\n\n, only output the result in format ```$filetype\n...\n```:\n```$filetype\n$text\n```",
        replace = true,
        extract = "```$filetype\n(.-)```",
    },
    Document_Code = {
        prompt = "Write a brief documentation comment for:\n```$filetype\n$text\n```\n\n, If documentation comments exist in the given code, use them as examples. Pay attention to the scope of the selected code (e.g. exported function/API vs implementation detail in a function), and use the idiomatic style for that type of code scope. Only generate the documentation for the selected code, do not generate the code itself again. Do not enclose any other code or comments besides the documentation. Enclose only the documentation for the given code and nothing else, the result should only be text and not a code.",
    },
}
