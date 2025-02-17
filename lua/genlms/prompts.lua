return {
    Generate = { prompt = "$input,just output the final text without additional quotes around it:\n$text", replace = true },
    Chat = { prompt = "$input" },
    Summarize = { prompt = "Summarize the following text:\n$text" },
    Ask = { prompt = "Here is the code:\n```$filetype\n$text\n```\n\n My question is: $input" },
    Change = {
        prompt = "Change the following code:\n```$filetype\n$text\n```\n\n,to my request: $input, just output the final text without additional quotes around it:\n$text",
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
        prompt = "Review the following code and make concise suggestions if needed:\n```$filetype\n$text\n```",
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
}
