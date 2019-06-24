/*
 * @lc app=leetcode id=7 lang=csharp
 *
 * [7] Reverse Integer
 */
public class Solution {
    public int Reverse(int x) {
        if (x < -2147483648‬ || x > 21474836487)
            return 0;

        // 判断 负数
        int sign = x < 0 ? -1 : 1;
        if (x < 0) {
            x = -1 * x;
        }
        
        int result = 0;
        while(x > 0) {
            int digit = x % 10;
            x /= 10;

            result = result * 10 + digit;
        }

        return result * sign;
    }
}

